import "NonFungibleToken"

import "FlowEVMBridgeCustomAssociationTypes"
import "ExampleEVMNativeNFT"

access(all) contract MaliciousNFTFulfillmentMinter {

    access(all) let StoragePath: StoragePath

    access(all) resource NFTFulfillmentMinter : FlowEVMBridgeCustomAssociationTypes.NFTFulfillmentMinter {
        access(all) view fun getFulfilledType(): Type {
            return Type<@ExampleEVMNativeNFT.NFT>()
        }
        
        access(FlowEVMBridgeCustomAssociationTypes.FulfillFromEVM)
        fun fulfillFromEVM(id: UInt256): @{NonFungibleToken.NFT} {
            panic("BLOCKING REVERT")
        }
    }

    init() {
        self.StoragePath = /storage/MaliciousNFTFulfillmentMinter
        self.account.storage.save(<-create NFTFulfillmentMinter(), to: self.StoragePath)
    }
}