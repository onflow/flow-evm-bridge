import "FungibleToken"
import "NonFungibleToken"
import "CrossVMMetadataViews"
import "EVM"

import "ScopedFTProviders"
import "FlowEVMBridgeCustomAssociationTypes"
import "FlowEVMBridgeCustomAssociations"
import "FlowEVMBridge"
import "FlowEVMBridgeConfig"

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
    let fulfillmentMinterCap: Capability<auth(FlowEVMBridgeCustomAssociationTypes.FulfillFromEVM) &{FlowEVMBridgeCustomAssociationTypes.NFTFulfillmentMinter}>?
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider
    let expectedAssociation: EVM.EVMAddress

    prepare(signer: auth(CopyValue, BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {
        /* --- Assign registration fields --- */
        //
        self.nftType = CompositeType(nftTypeIdentifier) ?? panic("Could not construct type from identifier ".concat(nftTypeIdentifier))
        if fulfillmentMinterPath != nil {
            assert(
                signer.storage.type(at: fulfillmentMinterPath!) != nil,
                message: "There was no resource found at provided path ".concat(fulfillmentMinterPath!.toString())
            )
            self.fulfillmentMinterCap = signer.capabilities.storage
                .issue<auth(FlowEVMBridgeCustomAssociationTypes.FulfillFromEVM) &{FlowEVMBridgeCustomAssociationTypes.NFTFulfillmentMinter}>(
                    fulfillmentMinterPath!
                )
        } else {
            self.fulfillmentMinterCap = nil
        }

        /* --- Configure a ScopedFTProvider --- */
        //
        // Issue and store bridge-dedicated Provider Capability in storage if necessary
        if signer.storage.type(at: FlowEVMBridgeConfig.providerCapabilityStoragePath) == nil {
            let providerCap = signer.capabilities.storage.issue<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(
                /storage/flowTokenVault
            )
            signer.storage.save(providerCap, to: FlowEVMBridgeConfig.providerCapabilityStoragePath)
        }
        // Copy the stored Provider capability and create a ScopedFTProvider
        let providerCapCopy = signer.storage.copy<Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>>(
                from: FlowEVMBridgeConfig.providerCapabilityStoragePath
            ) ?? panic("Invalid Provider Capability found in storage.")
        let providerFilter = ScopedFTProviders.AllowanceFilter(FlowEVMBridgeConfig.onboardFee)
        self.scopedProvider <- ScopedFTProviders.createScopedFTProvider(
                provider: providerCapCopy,
                filters: [ providerFilter ],
                expiration: getCurrentBlock().timestamp + 1.0
            )
        
        /* --- Assign the expected EVM address --- */
        //
        let resolver = getAccount(self.nftType.address!).contracts.borrow<&{NonFungibleToken}>(name: self.nftType.contractName!)
            ?? panic("Could not borrow NFT contract for NFT type \(nftTypeIdentifier)")
        let evmPointer = resolver.resolveContractView(resourceType: self.nftType, viewType: Type<CrossVMMetadataViews.EVMPointer>()) as! CrossVMMetadataViews.EVMPointer?
            ?? panic("Cross-VM NFTs must implement CrossVMMetadataViews.EVMPointer view but none was found for NFT \(nftTypeIdentifier)")
        self.expectedAssociation = evmPointer.evmContractAddress
    }

    execute {
        FlowEVMBridge.registerCrossVMNFT(
            type: self.nftType,
            fulfillmentMinter: self.fulfillmentMinterCap,
            feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
        )
        destroy self.scopedProvider
    }

    post {
        FlowEVMBridgeConfig.getEVMAddressAssociated(with: self.nftType)?.equals(self.expectedAssociation) ?? false:
        "Expected final association with \(nftTypeIdentifier) to be set to \(self.expectedAssociation.toString()) but found "
            .concat(FlowEVMBridgeConfig.getEVMAddressAssociated(with: self.nftType)?.toString() ?? "nil")
    }
}