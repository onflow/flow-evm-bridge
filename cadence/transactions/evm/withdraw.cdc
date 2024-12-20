import "FungibleToken"
import "FlowToken"

import "EVM"

/// Withdraws $FLOW from the signer's COA and deposits it into their FLOW vault in the Cadence environment
///
transaction(amount: UFix64) {

    let coa: auth(EVM.Withdraw) &EVM.CadenceOwnedAccount
    let vault: auth(FungibleToken.Withdraw) &FlowToken.Vault
    let preBalance: UFix64

    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Withdraw) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow reference to the signer's bridged account")
        
        self.vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's vault")
        self.preBalance = self.vault.balance
    }

    execute {
        let withdrawBalance = EVM.Balance(attoflow: 0)
        withdrawBalance.setFLOW(flow: amount)
        let bridgedVault <- self.coa.withdraw(balance: withdrawBalance) as! @{FungibleToken.Vault}
        self.vault.deposit(from: <-bridgedVault)
    }

    post {
        self.vault.balance == self.preBalance + amount: "Problem transferring Flow between environments!"
    }
}
