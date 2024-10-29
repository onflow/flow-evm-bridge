import "FungibleToken"
import "FlowToken"
import "ViewResolver"
import "NonFungibleToken"
import "FungibleTokenMetadataViews"

import "ScopedFTProviders"

import "EVM"

import "FlowEVMBridgeUtils"
import "FlowEVMBridge"
import "FlowEVMBridgeConfig"

/// Bridges a Vault from the signer's storage to any EVM address. The full amount to be transferred is sourced from the
/// signer's Cadence Vault & it's assumed the signer has sufficient funds to cover the amount requested to be bridged.
///
/// NOTE: The Vault being bridged must have first been onboarded to the bridge. This can be checked for with the method
///     FlowEVMBridge.typeRequiresOnboarding(type): Bool?
///
/// @param vaultIdentifier: The Cadence type identifier of the FungibleToken Vault to bridge
///     - e.g. vault.getType().identifier
/// @param amount: The amount of tokens to bridge from Cadence to the named recipient in EVM
/// @param recipient: The hex-encoded EVM address to send the tokens to
///
transaction(vaultIdentifier: String, amount: UFix64, recipient: String) {

    let sentVault: @{FungibleToken.Vault}
    let requiresOnboarding: Bool
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider

    prepare(signer: auth(CopyValue, BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {
        /* --- Construct the Vault type --- */
        //
        // Construct the Vault type from the provided identifier
        let vaultType = CompositeType(vaultIdentifier)
            ?? panic("Could not construct Vault type from identifier: ".concat(vaultIdentifier))
        // Parse the Vault identifier into its components
        let tokenContractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: vaultType)
            ?? panic("Could not get contract address from identifier: ".concat(vaultIdentifier))
        let tokenContractName = FlowEVMBridgeUtils.getContractName(fromType: vaultType)
            ?? panic("Could not get contract name from identifier: ".concat(vaultIdentifier))
        
        /* --- Retrieve the funds --- */
        //
        // Borrow a reference to the FungibleToken Vault
        let viewResolver = getAccount(tokenContractAddress).contracts.borrow<&{ViewResolver}>(name: tokenContractName)
            ?? panic("Could not borrow ViewResolver from FungibleToken contract with name"
                .concat(tokenContractName).concat(" and address ")
                .concat(tokenContractAddress.toString()))
        let vaultData = viewResolver.resolveContractView(
                resourceType: nil,
                viewType: Type<FungibleTokenMetadataViews.FTVaultData>()
            ) as! FungibleTokenMetadataViews.FTVaultData?
            ?? panic("Could not resolve FTVaultData view for Vault type ".concat(vaultType.identifier))
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
                from: vaultData.storagePath
            ) ?? panic("Could not borrow FungibleToken Vault from storage path ".concat(vaultData.storagePath.toString()))

        // Withdraw the requested balance & set a cap on the withdrawable bridge fee
        self.sentVault <- vault.withdraw(amount: amount)
        var approxFee = FlowEVMBridgeUtils.calculateBridgeFee(
                bytes: 400_000 // 400 kB as upper bound on movable storage used in a single transaction
            )
        // Determine if the Vault requires onboarding - this impacts the fee required
        self.requiresOnboarding = FlowEVMBridge.typeRequiresOnboarding(self.sentVault.getType())
            ?? panic("Bridge does not support the requested asset type ".concat(vaultIdentifier))
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
        self.sentVault.getType().identifier == vaultIdentifier:
            "Attempting to send invalid vault type - requested: ".concat(vaultIdentifier)
            .concat(", sending: ").concat(self.sentVault.getType().identifier)
        self.sentVault.balance == amount: "Amount to be transferred does not match the requested amount"
    }

    execute {
        if self.requiresOnboarding {
            // Onboard the Vault to the bridge
            FlowEVMBridge.onboardByType(
                self.sentVault.getType(),
                feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
            )
        }
        // Execute the bridge transaction
        let recipientEVMAddress = EVM.addressFromString(recipient)
        FlowEVMBridge.bridgeTokensToEVM(
            vault: <-self.sentVault,
            to: recipientEVMAddress,
            feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
        )
        // Destroy the ScopedFTProvider
        destroy self.scopedProvider
    }
}
