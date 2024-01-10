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
        switch forType {
            case forType.isSubtype(of: @{FungibleToken.Vault}):
                return self.lockerContractCodeChunks[0].decodeHex()
            case forType.isSubtype(of: @{NonFungibleToken.NFT}):
                return self.lockerContractCodeChunks[1].decodeHex()
            default:
                return nil
        }
    }
    /// Serves bridged asset contract code for a given type, deriving the contract name from the EVM contract info
    // TODO: Consider adding the values we would need to derive from instead of abstracting EVM calls in scope
    // access(all) fun getBridgedAssetContractCode(forEVMContract: EVM.EVMAddress): [UInt8]?

    access(self) fun getNFTLockerContractCode(forType: Type): [UInt8]? {
        if let contractName: String = FlowEVMBridgeUtils.deriveLockerContractName(forType: forType) {
            let contraNameHex: String = String.encodeHex(contractName.utf8)

            // Construct the contract code from the templated chunked contract hex
            let code: [UInt8] = []
            for i, chunk in self.lockerContractCodeChunks {
                code.appendAll(chunk.decodeHex())
                // No need to append the contract name after the last chunk
                if i == self.lockerContractCodeChunks.length - 1 {
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
}``