import "FungibleToken"
import "NonFungibleToken"

import "FlowEVMBridgeUtils"

/// Helper contract serving templates
//
// TODO:
// - [ ] Add support for:
//      - [ ] Token locker contracts
//      - [ ] Bridged NFT contracts
//      - [ ] Bridged token contracts
access(all) contract FlowEVMBridgeTemplates {

    access(self) let nftLockerContractCodeChunks: [String]
    // access(self) let tokenLockerContractCodeChunks: [String]
    // access(self) let nftContractCodeChunks: [String]
    // access(self) let tokenContractCodeChunks: [String]

    /// Serves Locker contract code for a given type, deriving the contract name from the type identifier
    access(all) fun getLockerContractCode(forType: Type): [UInt8]? {
        if forType.isSubtype(of: Type<@{FungibleToken.Vault}>()) && !forType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            return self.getNFTLockerContractCode(forType: forType)
        } else if !forType.isSubtype(of: Type<@{FungibleToken.Vault}>()) && forType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            // TODO
            return nil
        }
        return nil
    }
    /// Serves bridged asset contract code for a given type, deriving the contract name from the EVM contract info
    // TODO: Consider adding the values we would need to derive from instead of abstracting EVM calls in scope
    // access(all) fun getBridgedAssetContractCode(forEVMContract: EVM.EVMAddress): [UInt8]?

    access(self) fun getNFTLockerContractCode(forType: Type): [UInt8]? {
        if let contractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: forType) {
            let contraNameHex: String = String.encodeHex(contractName.utf8)

            // Construct the contract code from the templated chunked contract hex
            let code: [UInt8] = []
            for i, chunk in self.nftLockerContractCodeChunks {
                code.appendAll(chunk.decodeHex())
                // No need to append the contract name after the last chunk
                if i == self.nftLockerContractCodeChunks.length - 1 {
                    break
                }
                code.appendAll(contraNameHex.decodeHex())
            }
            return code
        }

        return nil
    }

    init(nftLockerContractCodeChunks: [String]) {
        self.nftLockerContractCodeChunks = nftLockerContractCodeChunks
        // self.tokenLockerContractCodeChunks = tokenLockerContractCodeChunks
        // self.nftContractCodeChunks = nftContractCodeChunks
        // self.tokenContractCodeChunks = tokenContractCodeChunks
    }
}
