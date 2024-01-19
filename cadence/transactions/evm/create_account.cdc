import "EVM"
import "FungibleToken"
import "FlowToken"

/// Creates a COA and saves it in the signer's Flow account & passing the given value of Flow into FlowEVM
transaction(amount: UFix64) {
    let sentVault: @FlowToken.Vault
    let auth: auth(Storage) &Account

    prepare(signer: auth(Storage) &Account) {
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not borrow reference to the owner's Vault!")

        self.sentVault <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault
        self.auth = signer
    }

    execute {
        let account <- EVM.createBridgedAccount()
        account.address().deposit(from: <-self.sentVault)

        log(account.balance())
        self.auth.storage.save<@EVM.BridgedAccount>(<-account, to: StoragePath(identifier: "evm")!)
    }
}
