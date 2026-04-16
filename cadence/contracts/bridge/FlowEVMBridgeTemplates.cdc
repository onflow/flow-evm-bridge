import "FungibleToken"
import "NonFungibleToken"

import "EVM"

import "FlowEVMBridgeUtils"

/// This contract serves Cadence code from chunked templates, replacing the contract name with the name derived from
/// given arguments - either Cadence Type or EVM contract address.
///
access(all)
contract FlowEVMBridgeTemplates {

    /// Canonical path for the Admin resource
    access(all)
    let AdminStoragePath: StoragePath
    /// Chunked Hex-encoded Cadence contract code, to be joined on derived contract name
    access(self)
    let templateCodeChunks: {String: [[UInt8]]}

    /// Emitted whenever there is a change to templated code
    access(all)
    event Updated(name: String, isNew: Bool?)

    /**************
        Getters
     **************/

    /// Serves bridged asset contract code for a given type, deriving the contract name from the EVM contract info
    access(all)
    fun getBridgedAssetContractCode(_ cadenceContractName: String, isERC721: Bool): [UInt8]? {
        if isERC721 {
            return self.getBridgedNFTContractCode(contractName: cadenceContractName)
        } else {
            return self.getBridgedTokenContractCode(contractName: cadenceContractName)
        }
    }

    /**************
        Internal
     **************/

    access(self)
    fun getBridgedNFTContractCode(contractName: String): [UInt8]? {
        if let chunks = self.templateCodeChunks["bridgedNFT"] {
            return self.joinChunks(chunks, with: String.encodeHex(contractName.utf8))
        }
        return nil
    }

    access(self)
    fun getBridgedTokenContractCode(contractName: String): [UInt8]? {
        if let chunks = self.templateCodeChunks["bridgedToken"] {
            return self.joinChunks(chunks, with: String.encodeHex(contractName.utf8))
        }
        return nil
    }

    access(self)
    fun joinChunks(_ chunks: [[UInt8]], with name: String): [UInt8] {
        let nameBytes: [UInt8] = name.decodeHex()
        let code: [UInt8] = []
        for i, chunk in chunks {
            code.appendAll(chunk)
            // No need to append the contract name after the last chunk
            if i == chunks.length - 1 {
                break
            }
            code.appendAll(nameBytes)
        }
        return code
    }

    /************
        Admin
     ************/

    /// Resource enabling updates to the contract template code
    ///
    access(all)
    resource Admin {

        /// Adds a new template to the templateCodeChunks mapping, preventing overwrites of existing templates
        ///
        /// @param newTemplate: The name of the new template
        /// @param chunks: The chunks of hex-encoded Cadence contract code
        ///
        /// @emits Updated with the name of the template and `isNew` set to true by way of the pre-condition
        ///
        access(all)
        fun addNewContractCodeChunks(newTemplate: String, chunks: [String]) {
            pre {
                FlowEVMBridgeTemplates.templateCodeChunks[newTemplate] == nil: "Code already exists for template"
            }
            self.upsertContractCodeChunks(forTemplate: newTemplate, chunks: chunks)
        }

        /// Upserts the contract code chunks for a given template, overwriting the existing template if exists
        ///
        /// @param newTemplate: The name of the new template
        /// @param chunks: The chunks of hex-encoded Cadence contract code
        ///
        /// @emits Updated with the name of the template and a boolean indicating if it was a newly named
        ///     template or an existing one was overwritten
        ///
        access(all)
        fun upsertContractCodeChunks(forTemplate: String, chunks: [String]) {
            let byteChunks: [[UInt8]] = []
            for chunk in chunks {
                byteChunks.append(chunk.decodeHex())
            }

            let isNew = FlowEVMBridgeTemplates.templateCodeChunks[forTemplate] == nil
            emit Updated(name: forTemplate, isNew: isNew)

            FlowEVMBridgeTemplates.templateCodeChunks[forTemplate] = byteChunks
        }

        /// Removes the template from the templateCodeChunks mapping
        ///
        /// @param name: The name of the template to remove
        ///
        /// @return true if the template was removed, false if it did not exist
        ///
        /// @emits Updated with the name of the template and `isNew` set `nil`
        ///
        access(all)
        fun removeTemplate(name: String): Bool {
            if let removed = FlowEVMBridgeTemplates.templateCodeChunks.remove(key: name) {
                emit Updated(name: name, isNew: nil)
                return true
            }
            return false
        }
    }

    init() {
        self.AdminStoragePath = /storage/flowEVMBridgeTemplatesAdmin
        self.templateCodeChunks = {}

        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}
