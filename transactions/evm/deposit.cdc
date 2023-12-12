import "FungibleToken"
import "FlowToken"

import "EVM"

transaction(amount: UFix64) {
    prepare(signer: AuthAccount) {
        if signer.type(at: EVM.StoragePath) == nil {
            signer.save(<-EVM.createBridgedAccount(), to: EVM.StoragePath)
        }
        if !signer.getCapability<&{EVM.BridgedAccountPublic}>(EVM.PublicPath).check() {
            signer.unlink(EVM.PublicPath)
            signer.link<&{EVM.BridgedAccountPublic}>(EVM.PublicPath, target: EVM.StoragePath)
        }
        let bridgedAccount = signer.borrow<&EVM.BridgedAccount>(from: EVM.StoragePath)
            ?? panic("Could not borrow reference to the signer's bridged account")
        
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's vault")

        let fromVault <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault
        bridgedAccount.deposit(from: <-fromVault)
    }
}
