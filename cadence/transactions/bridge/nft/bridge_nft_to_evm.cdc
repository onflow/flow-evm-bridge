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

/// Bridges an NFT from the signer's collection in Cadence to the signer's COA in FlowEVM
///
/// NOTE: This transaction also onboards the NFT to the bridge if necessary which may incur additional fees
///     than bridging an asset that has already been onboarded.
///
/// @param nftContractAddress: The Flow account address hosting the NFT-defining Cadence contract
/// @param nftContractName: The name of the NFT-defining Cadence contract
/// @param id: The Cadence NFT.id of the NFT to bridge to EVM
///
transaction(nftContractAddress: Address, nftContractName: String, id: UInt64) {
    
    let nft: @{NonFungibleToken.NFT}
    let coa: auth(EVM.Bridge) &EVM.CadenceOwnedAccount
    let requiresOnboarding: Bool
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider
    
    prepare(signer: auth(CopyValue, BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {
        /* --- Reference the signer's CadenceOwnedAccount --- */
        //
        // Borrow a reference to the signer's COA
        self.coa = signer.storage.borrow<auth(EVM.Bridge) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        
        /* --- Retrieve the NFT --- */
        //
        // Borrow a reference to the NFT collection, configuring if necessary
        let viewResolver = getAccount(nftContractAddress).contracts.borrow<&{ViewResolver}>(name: nftContractName)
            ?? panic("Could not borrow ViewResolver from NFT contract")
        let collectionData = viewResolver.resolveContractView(
                resourceType: nil,
                viewType: Type<MetadataViews.NFTCollectionData>()
            ) as! MetadataViews.NFTCollectionData? ?? panic("Could not resolve NFTCollectionData view")
        let collection = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(
                from: collectionData.storagePath
            ) ?? panic("Could not access signer's NFT Collection")

        // Withdraw the requested NFT & calculate the approximate bridge fee based on NFT storage usage
        let currentStorageUsage = signer.storage.used
        self.nft <- collection.withdraw(withdrawID: id)
        let withdrawnStorageUsage = signer.storage.used
        var approxFee = FlowEVMBridgeUtils.calculateBridgeFee(
                bytes: currentStorageUsage - withdrawnStorageUsage
            ) * 1.10
        // Determine if the NFT requires onboarding - this impacts the fee required
        self.requiresOnboarding = FlowEVMBridge.typeRequiresOnboarding(self.nft.getType())
            ?? panic("Bridge does not support this asset type")
        if self.requiresOnboarding {
            approxFee = approxFee + FlowEVMBridgeConfig.onboardFee
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
        let providerFilter = ScopedFTProviders.AllowanceFilter(approxFee)
        self.scopedProvider <- ScopedFTProviders.createScopedFTProvider(
                provider: providerCapCopy,
                filters: [ providerFilter ],
                expiration: getCurrentBlock().timestamp + 1.0
            )
    }

    execute {
        if self.requiresOnboarding {
            // Onboard the NFT to the bridge
            FlowEVMBridge.onboardByType(
                self.nft.getType(),
                feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
            )
        }
        // Execute the bridge
        self.coa.depositNFT(
            nft: <-self.nft,
            feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
        )
        // Destroy the ScopedFTProvider
        destroy self.scopedProvider
    }
}
