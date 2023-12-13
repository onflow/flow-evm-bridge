import "FungibleToken"
import "FlowToken"

import "EVM"

transaction(amount: UFix64) {
    let preBalance: UFix64
    let bridgedAccount: &EVM.BridgedAccount
    let signerVault: &FlowToken.Vault

    prepare(signer: AuthAccount) {
        let storagePath = StoragePath(identifier: "evm")!
        // Create BridgedAccount if none exists
        if signer.type(at: storagePath) == nil {
            signer.save(<-EVM.createBridgedAccount(), to: storagePath)
        }

        // Reference the signer's BridgedAccount
        self.bridgedAccount = signer.borrow<&EVM.BridgedAccount>(from: storagePath)
            ?? panic("Could not borrow reference to the signer's bridged account")

        // Note the pre-transfer balance
        self.preBalance = self.bridgedAccount.balance().flow
    
        // Reference the signer's FlowToken Vault
        self.signerVault = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's vault")
    }

    execute {
        // Withdraw tokens from the signer's vault
        let fromVault <- self.signerVault.withdraw(amount: amount) as! @FlowToken.Vault
        // Deposit tokens into the bridged account
        self.bridgedAccount.deposit(from: <-fromVault)
    }

    post {
        self.preBalance + amount == self.bridgedAccount.balance().flow: "Error executing transfer!"
    }
}
