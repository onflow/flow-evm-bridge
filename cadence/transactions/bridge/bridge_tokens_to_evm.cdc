import "FungibleToken"
import "ViewResolver"
import "FungibleTokenMetadataViews"
import "FlowToken"

import "ScopedFTProviders"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// Bridges a Vault from the signer's storage to the signer's COA in EVM
/// NOTE: The Vault being bridged must have first been onboarded to the bridge. This can be checked for with the method
///     FlowEVMBridge.typeRequiresOnboarding(type): Bool?
///
/// @param tokenContractAddress: The Flow account address hosting the FT-defining Cadence contract
/// @param tokenContractName: The name of the Vault-defining Cadence contract
/// @param amount: The amount of tokens to bridge from EVM
///
transaction(tokenContractAddress: Address, tokenContractName: String, amount: UFix64) {
    
    let sentVault: @{FungibleToken.Vault}
    let coa: auth(EVM.Bridge) &EVM.CadenceOwnedAccount
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider
    
    prepare(signer: auth(CopyValue, BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {
        /* --- Reference the signer's CadenceOwnedAccount --- */
        //
        // Borrow a reference to the signer's COA
        self.coa = signer.storage.borrow<auth(EVM.Bridge) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        
        /* --- Retrieve the NFT --- */
        //
        // Borrow a reference to the FungibleToken Vault
        let viewResolver = getAccount(tokenContractAddress).contracts.borrow<&{ViewResolver}>(name: tokenContractName)
            ?? panic("Could not borrow ViewResolver from NFT contract")
        let vaultData = viewResolver.resolveContractView(
                resourceType: nil,
                viewType: Type<FungibleTokenMetadataViews.FTVaultData>()
            ) as! FungibleTokenMetadataViews.FTVaultData? ?? panic("Could not resolve FTVaultData view")
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
                from: vaultData.storagePath
            ) ?? panic("Could not access signer's FungibleToken Vault")

        // Withdraw the requested NFT & calculate the approximate bridge fee based on NFT storage usage
        let currentStorageUsage = signer.storage.used
        self.sentVault <- vault.withdraw(amount: amount)
        let withdrawnStorageUsage = signer.storage.used
        // Approximate the bridge fee based on the difference in storage usage with some buffer
        let approxFee = FlowEVMBridgeUtils.calculateBridgeFee(
                used: currentStorageUsage - withdrawnStorageUsage,
                includeBase: true
            ) * 1.10

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
        // Execute the bridge
        self.coa.depositTokens(
            vault: <-self.sentVault,
            feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
        )
        // Destroy the ScopedFTProvider
        destroy self.scopedProvider
    }
}
