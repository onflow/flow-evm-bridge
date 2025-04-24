import "FungibleToken"
import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FlowToken"

import "ScopedFTProviders"

import "EVM"

import "CrossVMNFT"
import "FlowEVMBridge"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// This transaction moves bridged NFTs to EVM then back from EVM for the purpose of migrating bridged NFT to updated,
/// project-defined NFTs after the cross-VM association has been registered with the bridge. Registering as a
/// cross-VM association is a project-initiated process, allowing developers to define both Cadence & Solidity
/// implementations. And this transaction allows any users to effectively migrate original bridged Cadence NFTs to
/// acquire the updated, project-defined NFT.
///
/// NOTE: This is a computationally intensive transaction and the amount of NFTs that can be migrated at a time will
/// likely be limited in number.
///
/// @param nftIdentifier: The Cadence type identifier of the NFT to bridge - e.g. nft.getType().identifier
/// @param id: The Cadence NFT.id of the NFT to bridge to EVM
///
transaction(nftIdentifier: String, ids: [UInt64]) {

    let bridgedNFTType: Type
    let crossVMNFTType: Type
    let bridgedCollection: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}
    let crossVMCollection: &{NonFungibleToken.Collection}
    let coa: auth(EVM.Bridge) &EVM.CadenceOwnedAccount
    let requiresOnboarding: Bool
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider

    prepare(signer: auth(CopyValue, BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {
        /* --- Reference the signer's CadenceOwnedAccount --- */
        //
        // Borrow a reference to the signer's COA
        self.coa = signer.storage.borrow<auth(EVM.Bridge) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA signer's account at path /storage/evm")

        /* --- Construct the NFT type --- */
        //
        // Construct the NFT type from the provided identifier
        self.bridgedNFTType = CompositeType(nftIdentifier)
            ?? panic("Could not construct NFT type from identifier: ".concat(nftIdentifier))
        // Get the registered cross-VM NFT Type that has been registered to replace the bridged NFT Type
        let maybeCrossVMNFTType = FlowEVMBridgeConfig.getUpdatedCustomCrossVMType(self.bridgedNFTType)
        if maybeCrossVMNFTType == nil {
            panic("The NFT Type \(nftIdentifier) has not been updated with a custom cross-VM NFT or it has not been "
                .concat("registered with the VM bridge."))
        }
        self.crossVMNFTType = maybeCrossVMNFTType!
        // Parse the NFT identifier into its components
        let nftContractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: self.bridgedNFTType)
            ?? panic("Could not get contract address from identifier: \(nftIdentifier)")
        let nftContractName = FlowEVMBridgeUtils.getContractName(fromType: self.bridgedNFTType)
            ?? panic("Could not get contract name from identifier: \(nftIdentifier)")

        /* --- Retrieve the NFT --- */
        //
        // Borrow a reference to the NFT collection, configuring if necessary
        var viewResolver = getAccount(nftContractAddress).contracts.borrow<&{ViewResolver}>(name: nftContractName)
            ?? panic("Could not borrow ViewResolver from NFT contract with name \(nftContractName) and address "
                .concat(nftContractAddress.toString()))
        var collectionData = viewResolver.resolveContractView(
                resourceType: self.bridgedNFTType,
                viewType: Type<MetadataViews.NFTCollectionData>()
            ) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not resolve NFTCollectionData view for NFT type ".concat(self.bridgedNFTType.identifier))
        self.bridgedCollection = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(
                from: collectionData.storagePath
            ) ?? panic("Could not borrow a NonFungibleToken Collection from the signer's storage path "
                .concat(collectionData.storagePath.toString()))

        // Withdraw the requested NFT & set a cap on the withdrawable bridge fee
        var approxFee = FlowEVMBridgeUtils.calculateBridgeFee(
                bytes: 400_000 // 400 kB as upper bound on movable storage used in a single transaction
            ) + (FlowEVMBridgeConfig.baseFee * UFix64(ids.length) * 2.0)
        // Determine if the NFT requires onboarding - this impacts the fee required
        self.requiresOnboarding = FlowEVMBridge.typeRequiresOnboarding(self.bridgedNFTType)
            ?? panic("Bridge does not support the requested asset type ".concat(nftIdentifier))
        // Add the onboarding fee if onboarding is necessary
        if self.requiresOnboarding {
            approxFee = approxFee + FlowEVMBridgeConfig.onboardFee
        }

        /* --- Assign the updated cross-VM NFT collection --- */
        //
        // Borrow a reference to the cross-VM NFT collection, configuring if necessary
        let crossVMNFTContractAddress = self.crossVMNFTType.address!
        let crossVMNFTContractName = self.crossVMNFTType.contractName!
        viewResolver = getAccount(crossVMNFTContractAddress).contracts.borrow<&{ViewResolver}>(name: crossVMNFTContractName)
            ?? panic("Could not borrow ViewResolver from NFT contract with name \(crossVMNFTContractName) and address "
                .concat(crossVMNFTContractAddress.toString()))
        collectionData = viewResolver.resolveContractView(
                resourceType: self.crossVMNFTType,
                viewType: Type<MetadataViews.NFTCollectionData>()
            ) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not resolve NFTCollectionData view for NFT type \(self.crossVMNFTType.identifier)")
        if signer.storage.type(at: collectionData.storagePath) == nil {
            signer.storage.save(<-collectionData.createEmptyCollection(), to: collectionData.storagePath)
            signer.capabilities.unpublish(collectionData.publicPath)
            let collectionCap = signer.capabilities.storage.issue<&{NonFungibleToken.Collection}>(collectionData.storagePath)
            signer.capabilities.publish(collectionCap, at: collectionData.publicPath)
        }
        self.crossVMCollection = signer.storage.borrow<&{NonFungibleToken.Collection}>(
                from: collectionData.storagePath
            ) ?? panic("Could not borrow a NonFungibleToken Collection from the signer's storage path "
                .concat(collectionData.storagePath.toString()))

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

    execute {
        if self.requiresOnboarding {
            // Onboard the NFT to the bridge
            FlowEVMBridge.onboardByType(
                self.bridgedNFTType,
                feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
            )
        }

        // Iterate over requested IDs and bridge each NFT to the signer's COA in EVM
        for id in ids {
            // Withdraw the NFT & ensure it's the correct type
            let nft <-self.bridgedCollection.withdraw(withdrawID: id)
            assert(nft.getType() == self.bridgedNFTType,
                message: "Bridged nft type mismatch - requested: \(self.bridgedNFTType.identifier), received: \(nft.getType().identifier)"
            )
            // Execute the bridge to EVM for the current ID
            let feeProvider = &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}

            let bridgedNFT <- nft as! @{CrossVMNFT.EVMNFT}
            let evmID = bridgedNFT.evmID
            self.coa.depositNFT(
                nft: <-bridgedNFT,
                feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
            )
            let crossVMNFT <- self.coa.withdrawNFT(
                    type: self.bridgedNFTType,
                    id: evmID,
                    feeProvider: feeProvider
                )
            self.crossVMCollection.deposit(token: <-crossVMNFT)
        }

        // Destroy the ScopedFTProvider
        destroy self.scopedProvider
    }
}
