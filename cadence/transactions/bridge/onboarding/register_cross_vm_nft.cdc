import "FlowEVMBridgeCustomAssociations"
import "FlowEVMBridge"

/// This transaction will register an NFT type as a custom cross-VM NFT. The Cadence contract must implement the
/// CrossVMMetadata.EVMPointer view and the corresponding ERC721 must implement ICrossVM interface such that the Type
/// points to the EVM contract and vice versa. If the NFT is EVM-native, a
/// FlowEVMBridgeCustomAssociations.NFTFulfillmentMinter Capability must be provided, allowing the bridge to fulfill
/// requests moving the ERC721 from EVM into Cadence.
///
/// See FLIP-318 for more information on implementing custom cross-VM NFTs: https://github.com/onflow/flips/issues/318
/// 
/// @param nftTypeIdentifer: The type identifier of the NFT being registered as a custom cross-VM implementation
/// @param fulfillmentMinterPath: The StoragePath where the NFTFulfillmentMinter is stored
///
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