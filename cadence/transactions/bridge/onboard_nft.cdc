import "FungibleToken"
import "NonFungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeConfig"

/// This transaction onboards the NFT type to the bridge, configuring the bridge to move NFTs between environments
/// NOTE: This must be done before bridging a Flow-native NFT to Flow EVM
///
transaction(identifier: String) {

    let nftType: Type
    let tollFee: @FlowToken.Vault
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Construct the type from the identifier
        self.nftType = CompositeType(identifier) ?? panic("Invalid type identifier")
        // Pay the bridge toll
        let vault = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not access signer's FlowToken Vault")
        self.tollFee <- vault.withdraw(amount: FlowEVMBridgeConfig.fee) as! @FlowToken.Vault
    }

    // Added for context - how to check if a type requires onboarding to the bridge
    pre {
        FlowEVMBridge.typeRequiresOnboarding(self.nftType) != nil: "Requesting to bridge unsupported asset type"
        FlowEVMBridge.typeRequiresOnboarding(self.nftType) == true: "This NFT type has already been onboarded"
    }

    execute {
        // Onboard the NFT Type
        FlowEVMBridge.onboardByType(self.nftType, tollFee: <-self.tollFee)
    }
}
