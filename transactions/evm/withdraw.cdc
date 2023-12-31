import "FungibleToken"
import "FlowToken"

import "EVM"

transaction(amount: UFix64) {
    prepare(signer: AuthAccount) {
        let bridgedAccount = signer.borrow<&EVM.BridgedAccount>(from: EVM.StoragePath)
            ?? panic("Could not borrow reference to the signer's bridged account")
        
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's vault")

        let bridgedVault <- bridgedAccount.withdraw(balance: EVM.Balance(flow: 10.0)) as! @FungibleToken.Vault
        vaultRef.deposit(from: <-bridgedVault)
    }
}
