import "FungibleToken"
import "MetadataViews"

import "EVM"

/// Contract defining cross-VM asset interfaces
access(all) contract CrossVMNFT {

    access(all) entitlement Bridgeable

    access(all) struct URI : MetadataViews.File {
        access(self) let value: String

        access(all) view fun uri(): String {
            return self.value
        }

        init(_ value: String) {
            self.value = value
        }
    }

    access(all) struct BridgedMetadata {
        access(all) let name: String
        access(all) let symbol: String
        access(all) let uri: URI

        init(name: String, symbol: String, uri: URI) {
            self.name = name
            self.symbol = symbol
            self.uri = uri
        }
    }

    access(all) resource interface EVMNFT {
        access(all) let evmID: UInt256
        access(all) let name: String
        access(all) let symbol: String
        access(all) fun getEVMContractAddress(): EVM.EVMAddress
        access(all) fun tokenURI(): String
    }
    /// Enables a bridging entrypoint on an implementing Collection
    access(all) resource interface EVMBridgeableCollection {
        access(all) fun borrowEVMNFT(id: UInt64): &{EVMNFT}
        access(Bridgeable) fun bridgeToEVM(id: UInt64, to: EVM.EVMAddress, tollFee: @{FungibleToken.Vault})
    }
}
