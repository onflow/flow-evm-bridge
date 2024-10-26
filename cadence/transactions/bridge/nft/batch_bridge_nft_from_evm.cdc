import "FungibleToken"
import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FlowToken"

import "ScopedFTProviders"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// This transaction bridges NFTs from EVM to Cadence assuming the NFT has already been onboarded to the FlowEVMBridge
/// NOTE: The ERC721 must have first been onboarded to the bridge. This can be checked via the method
///     FlowEVMBridge.evmAddressRequiresOnboarding(address: self.evmContractAddress)
///
/// @param nftIdentifier: The Cadence type identifier of the NFT to bridge - e.g. nft.getType().identifier
/// @param ids: The ERC721 ids of the NFTs to bridge to Cadence from EVM
///
transaction(nftIdentifier: String, ids: [UInt256]) {

    let nftType: Type
    let collection: &{NonFungibleToken.Collection}
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider
    let coa: auth(EVM.Bridge) &EVM.CadenceOwnedAccount

    prepare(signer: auth(BorrowValue, CopyValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {
        /* --- Reference the signer's CadenceOwnedAccount --- */
        //
        // Borrow a reference to the signer's COA
        self.coa = signer.storage.borrow<auth(EVM.Bridge) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")

        /* --- Construct the NFT type --- */
        //
        // Construct the NFT type from the provided identifier
        self.nftType = CompositeType(nftIdentifier)
            ?? panic("Could not construct NFT type from identifier: ".concat(nftIdentifier))
        // Parse the NFT identifier into its components
        let nftContractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: self.nftType)
            ?? panic("Could not get contract address from identifier: ".concat(nftIdentifier))
        let nftContractName = FlowEVMBridgeUtils.getContractName(fromType: self.nftType)
            ?? panic("Could not get contract name from identifier: ".concat(nftIdentifier))

        /* --- Reference the signer's NFT Collection --- */
        //
        // Borrow a reference to the NFT collection, configuring if necessary
        let viewResolver = getAccount(nftContractAddress).contracts.borrow<&{ViewResolver}>(name: nftContractName)
            ?? panic("Could not borrow ViewResolver from NFT contract")
        let collectionData = viewResolver.resolveContractView(
                resourceType: self.nftType,
                viewType: Type<MetadataViews.NFTCollectionData>()
            ) as! MetadataViews.NFTCollectionData? ?? panic("Could not resolve NFTCollectionData view")
        if signer.storage.borrow<&{NonFungibleToken.Collection}>(from: collectionData.storagePath) == nil {
            signer.storage.save(<-collectionData.createEmptyCollection(), to: collectionData.storagePath)
            signer.capabilities.unpublish(collectionData.publicPath)
            let collectionCap = signer.capabilities.storage.issue<&{NonFungibleToken.Collection}>(collectionData.storagePath)
            signer.capabilities.publish(collectionCap, at: collectionData.publicPath)
        }
        self.collection = signer.storage.borrow<&{NonFungibleToken.Collection}>(from: collectionData.storagePath)
            ?? panic("Could not borrow collection from storage path")

        /* --- Configure a ScopedFTProvider --- */
        //
        // Set a cap on the withdrawable bridge fee
        var approxFee = FlowEVMBridgeUtils.calculateBridgeFee(
                bytes: 400_000 // 400 kB as upper bound on movable storage used in a single transaction
            ) + (FlowEVMBridgeConfig.baseFee * UFix64(ids.length))
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
        let providerFilter = ScopedFTProviders.AllowanceFilter(approxFee)
        self.scopedProvider <- ScopedFTProviders.createScopedFTProvider(
                provider: providerCapCopy,
                filters: [ providerFilter ],
                expiration: getCurrentBlock().timestamp + 1.0
            )
    }

    execute {
        // Iterate over the provided ids
        for id in ids {
            // Execute the bridge
            let nft: @{NonFungibleToken.NFT} <- self.coa.withdrawNFT(
                type: self.nftType,
                id: id,
                feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
            )
            // Ensure the bridged nft is the correct type
            assert(
                nft.getType() == self.nftType,
                message: "Bridged nft type mismatch - requeswted: ".concat(self.nftType.identifier)
                    .concat(", received: ").concat(nft.getType().identifier)
            )
            // Deposit the bridged NFT into the signer's collection
            self.collection.deposit(token: <-nft)
        }
        // Destroy the ScopedFTProvider
        destroy self.scopedProvider
    }
}
