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
/// @param nftIdentifier: The Cadence type identifier of the NFT to bridge - e.g. nft.getType().identifier
/// @param id: The Cadence NFT.id of the NFT to bridge to EVM
///
transaction(nftIdentifier: String, id: UInt64) {
    
    let nft: @{NonFungibleToken.NFT}
    let coa: auth(EVM.Bridge) &EVM.CadenceOwnedAccount
    let requiresOnboarding: Bool
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider
    
    prepare(signer: auth(CopyValue, BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {
        /* --- Reference the signer's CadenceOwnedAccount --- */
        //
        // Borrow a reference to the signer's COA
        self.coa = signer.storage.borrow<auth(EVM.Bridge) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA signer's account at path /storage/evm")
        
        /* --- Construct the NFT type --- */
        //
        // Construct the NFT type from the provided identifier
        let nftType = CompositeType(nftIdentifier)
            ?? panic("Could not construct NFT type from identifier: ".concat(nftIdentifier))
        // Parse the NFT identifier into its components
        let nftContractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: nftType)
            ?? panic("Could not get contract address from identifier: ".concat(nftIdentifier))
        let nftContractName = FlowEVMBridgeUtils.getContractName(fromType: nftType)
            ?? panic("Could not get contract name from identifier: ".concat(nftIdentifier))

        /* --- Retrieve the NFT --- */
        //
        // Borrow a reference to the NFT collection, configuring if necessary
        let viewResolver = getAccount(nftContractAddress).contracts.borrow<&{ViewResolver}>(name: nftContractName)
            ?? panic("Could not borrow ViewResolver from NFT contract with name "
                .concat(nftContractName).concat(" and address ")
                .concat(nftContractAddress.toString()))
        let collectionData = viewResolver.resolveContractView(
                resourceType: nftType,
                viewType: Type<MetadataViews.NFTCollectionData>()
            ) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not resolve NFTCollectionData view for NFT type ".concat(nftType.identifier))
        let collection = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(
                from: collectionData.storagePath
            ) ?? panic("Could not borrow a NonFungibleToken Collection from the signer's storage path "
                .concat(collectionData.storagePath.toString()))

        // Withdraw the requested NFT & set a cap on the withdrawable bridge fee
        self.nft <- collection.withdraw(withdrawID: id)
        var approxFee = FlowEVMBridgeUtils.calculateBridgeFee(
                bytes: 400_000 // 400 kB as upper bound on movable storage used in a single transaction
            )
        // Determine if the NFT requires onboarding - this impacts the fee required
        self.requiresOnboarding = FlowEVMBridge.typeRequiresOnboarding(self.nft.getType())
            ?? panic("Bridge does not support the requested asset type ".concat(nftIdentifier))
        // Add the onboarding fee if onboarding is necessary
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
            ) ?? panic("Invalid FungibleToken Provider Capability found in storage at path "
                .concat(FlowEVMBridgeConfig.providerCapabilityStoragePath.toString()))
        let providerFilter = ScopedFTProviders.AllowanceFilter(approxFee)
        self.scopedProvider <- ScopedFTProviders.createScopedFTProvider(
                provider: providerCapCopy,
                filters: [ providerFilter ],
                expiration: getCurrentBlock().timestamp + 1.0
            )
    }

    pre {
        self.nft.getType().identifier == nftIdentifier:
            "Attempting to send invalid nft type - requested: ".concat(nftIdentifier)
            .concat(", sending: ").concat(self.nft.getType().identifier)
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
