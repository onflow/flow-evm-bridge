import "FungibleToken"
import "FlowToken"

import "EVM"

/// Withdraws $FLOW from the signer's COA and deposits it into their FLOW vault in the Cadence environment
///
transaction(amount: UFix64) {

    let coa: &EVM.BridgedAccount
    let vault: auth(FungibleToken.Withdrawable) &FlowToken.Vault
    let preBalance: UFix64

    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<&EVM.BridgedAccount>(from: /storage/evm)
            ?? panic("Could not borrow reference to the signer's bridged account")
        
        self.vault = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's vault")
        self.preBalance = self.vault.balance
    }

    execute {
        let bridgedVault <- self.coa.withdraw(balance: EVM.Balance(flow: amount)) as! @{FungibleToken.Vault}
        self.vault.deposit(from: <-bridgedVault)
    }

    post {
        self.vault.balance == self.preBalance + amount: "Problem transfering Flow between environments!"
    }
}
