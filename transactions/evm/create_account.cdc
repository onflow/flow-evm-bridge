import "EVM"
import "FungibleToken"
import "FlowToken"

transaction(amount: UFix64) {
    let sentVault: @FlowToken.Vault
    let auth: AuthAccount

    prepare(signer: AuthAccount) {
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.sentVault <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault
        self.auth = signer
    }

    execute {
        let account <- EVM.createBridgedAccount()
        account.address().deposit(from: <-self.sentVault)

        log(account.balance())
        self.auth.save<@EVM.BridgedAccount>(<-account, to: StoragePath(identifier: "evm")!)
    }
}
