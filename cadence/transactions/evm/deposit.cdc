import "FungibleToken"
import "FlowToken"

import "EVM"

/// Deposits $FLOW to the signer's COA in FlowEVM
///
transaction(amount: UFix64) {
    let preBalance: UFix64
    let coa: &EVM.CadenceOwnedAccount
    let signerVault: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(signer: auth(BorrowValue, SaveValue) &Account) {
        let storagePath = StoragePath(identifier: "evm")!
        // Create coa if none exists
        if signer.storage.type(at: storagePath) == nil {
            signer.storage.save(<-EVM.createCadenceOwnedAccount(), to: storagePath)
        }

        // Reference the signer's coa
        self.coa = signer.storage.borrow<&EVM.CadenceOwnedAccount>(from: storagePath)
            ?? panic("Could not borrow reference to the signer's bridged account")

        // Note the pre-transfer balance
        self.preBalance = self.coa.balance().inFLOW()
    
        // Reference the signer's FlowToken Vault
        self.signerVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's vault")
    }

    execute {
        // Withdraw tokens from the signer's vault
        let fromVault <- self.signerVault.withdraw(amount: amount) as! @FlowToken.Vault
        // Deposit tokens into the COA
        self.coa.deposit(from: <-fromVault)
    }

    post {
        // Can't do the following since .balance() isn't view
        self.coa.balance().inFLOW() == self.preBalance + amount: "Error executing transfer!"
    }
}
