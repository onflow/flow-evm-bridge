import "FungibleToken"
import "FungibleTokenMetadataViews"
import "ViewResolver"
import "MetadataViews"
import "FlowToken"

import "ScopedFTProviders"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// This transaction bridges fungible tokens from EVM to Cadence assuming it has already been onboarded to the
/// FlowEVMBridge.
///
/// NOTE: The ERC20 must have first been onboarded to the bridge. This can be checked via the method
///     FlowEVMBridge.evmAddressRequiresOnboarding(address: self.evmContractAddress)
///
/// @param vaultIdentifier: The Cadence type identifier of the FungibleToken Vault to bridge
///     - e.g. vault.getType().identifier
/// @param amount: The amount of tokens to bridge from EVM
///
transaction(vaultIdentifier: String, amount: UInt256) {

    let vaultType: Type
    let receiver: &{FungibleToken.Vault}
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider
    let coa: auth(EVM.Bridge) &EVM.CadenceOwnedAccount

    prepare(signer: auth(BorrowValue, CopyValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {
        /* --- Reference the signer's CadenceOwnedAccount --- */
        //
        // Borrow a reference to the signer's COA
        self.coa = signer.storage.borrow<auth(EVM.Bridge) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")

        /* --- Construct the Vault type --- */
        //
        // Construct the Vault type from the provided identifier
        self.vaultType = CompositeType(vaultIdentifier)
            ?? panic("Could not construct Vault type from identifier: ".concat(vaultIdentifier))
        // Parse the Vault identifier into its components
        let tokenContractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: self.vaultType)
            ?? panic("Could not get contract address from identifier: ".concat(vaultIdentifier))
        let tokenContractName = FlowEVMBridgeUtils.getContractName(fromType: self.vaultType)
            ?? panic("Could not get contract name from identifier: ".concat(vaultIdentifier))

        /* --- Reference the signer's Vault --- */
        //
        // Borrow a reference to the FungibleToken Vault, configuring if necessary
        let viewResolver = getAccount(tokenContractAddress).contracts.borrow<&{ViewResolver}>(name: tokenContractName)
            ?? panic("Could not borrow ViewResolver from FungibleToken contract")
        let vaultData = viewResolver.resolveContractView(
                resourceType: self.vaultType,
                viewType: Type<FungibleTokenMetadataViews.FTVaultData>()
            ) as! FungibleTokenMetadataViews.FTVaultData? ?? panic("Could not resolve FTVaultData view")
        // If the vault does not exist, create it and publish according to the contract's defined configuration
        if signer.storage.borrow<&{FungibleToken.Vault}>(from: vaultData.storagePath) == nil {
            signer.storage.save(<-vaultData.createEmptyVault(), to: vaultData.storagePath)

            signer.capabilities.unpublish(vaultData.receiverPath)
            signer.capabilities.unpublish(vaultData.metadataPath)

            let receiverCap = signer.capabilities.storage.issue<&{FungibleToken.Vault}>(vaultData.storagePath)
            let metadataCap = signer.capabilities.storage.issue<&{FungibleToken.Vault}>(vaultData.storagePath)

            signer.capabilities.publish(receiverCap, at: vaultData.receiverPath)
            signer.capabilities.publish(metadataCap, at: vaultData.metadataPath)
        }
        self.receiver = signer.storage.borrow<&{FungibleToken.Vault}>(from: vaultData.storagePath)
            ?? panic("Could not borrow Vault from storage path")

        /* --- Configure a ScopedFTProvider --- */
        //
        // Calculate the bridge fee - bridging from EVM consumes no storage, so flat fee
        let approxFee = FlowEVMBridgeUtils.calculateBridgeFee(bytes: 0)
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
        // Execute the bridge request
        let vault: @{FungibleToken.Vault} <- self.coa.withdrawTokens(
            type: self.vaultType,
            amount: amount,
            feeProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
        )
        // Ensure the bridged vault is the correct type
        assert(vault.getType() == self.vaultType, message: "Bridged vault type mismatch")
        // Deposit the bridged token into the signer's vault
        self.receiver.deposit(from: <-vault)
        // Destroy the ScopedFTProvider
        destroy self.scopedProvider
    }
}
