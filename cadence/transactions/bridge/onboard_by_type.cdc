import "FungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeConfig"

/// This transaction onboards the asset type to the bridge, configuring the bridge to move assets between environments
/// NOTE: This must be done before bridging a Cadence-native asset to EVM
///
transaction(identifier: String) {

    let type: Type
    let tollFee: @{FungibleToken.Vault}
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Construct the type from the identifier
        self.type = CompositeType(identifier) ?? panic("Invalid type identifier")
        // Pay the bridge toll
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not access signer's FlowToken Vault")
        self.tollFee <- vault.withdraw(amount: FlowEVMBridgeConfig.onboardFee)
    }

    // Added for context - how to check if a type requires onboarding to the bridge
    pre {
        FlowEVMBridge.typeRequiresOnboarding(self.type) != nil: "Requesting to bridge unsupported asset type"
        FlowEVMBridge.typeRequiresOnboarding(self.type) == true: "This Type has already been onboarded"
    }

    execute {
        // Onboard the asset Type
        FlowEVMBridge.onboardByType(self.type, tollFee: <-self.tollFee)
    }
}
