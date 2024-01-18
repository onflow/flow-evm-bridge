import "FungibleToken"
import "NonFungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridge"

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
        self.tollFee <- vault.withdraw(amount: FlowEVMBridge.fee) as! @FlowToken.Vault
    }

    execute {
        // Execute the bridge
        FlowEVMBridge.onboardNFT(type: self.nftType,tollFee: <-self.tollFee)
    }

    // Post-assert bridge onboarding completed successfully 
    post {
        FlowEVMBridge.typeRequiresOnboarding(self.nftType) == true: "Bridge was not configured for given type"
    }
}