import "FlowEVMBridgeCustomAssociations"
import "FlowEVMBridge"

transaction(nftTypeIdentifier: String, fulfillmentMinterPath: StoragePath?) {

    let nftType: Type
    let fulfillmentMinterCap: Capability<auth(FlowEVMBridgeCustomAssociations.FulfillFromEVM) &{FlowEVMBridgeCustomAssociations.NFTFulfillmentMinter}>?

    prepare(signer: auth(BorrowValue, StorageCapabilities) &Account) {
        self.nftType = CompositeType(nftTypeIdentifier) ?? panic("Could not construct type from identifier ".concat(nftTypeIdentifier))
        if fulfillmentMinterPath != nil {
            assert(
                signer.storage.type(at: fulfillmentMinterPath!) != nil,
                message: "There was no resource found at provided path ".concat(fulfillmentMinterPath!.toString())
            )
            self.fulfillmentMinterCap = signer.capabilities.storage
                .issue<auth(FlowEVMBridgeCustomAssociations.FulfillFromEVM) &{FlowEVMBridgeCustomAssociations.NFTFulfillmentMinter}>(
                    fulfillmentMinterPath!
                )
        } else {
            self.fulfillmentMinterCap = nil
        }
    }

    execute {
        FlowEVMBridge.registerCrossVMNFT(type: self.nftType, fulfillmentMinter: self.fulfillmentMinterCap)
    }

    // post {} - TODO: assert the association has been updated
}