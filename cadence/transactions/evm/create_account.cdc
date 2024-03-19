import "EVM"
import "FungibleToken"
import "FlowToken"

/// Creates a COA and saves it in the signer's Flow account & passing the given value of Flow into FlowEVM
///
transaction(amount: UFix64) {
    let sentVault: @FlowToken.Vault
    let auth: auth(IssueStorageCapabilityController, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account

    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not borrow reference to the owner's Vault!")

        self.sentVault <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault
        self.auth = signer
    }

    execute {
        let coa <- EVM.createCadenceOwnedAccount()
        coa.deposit(from: <-self.sentVault)

        log(coa.balance().inFLOW())
        let storagePath = StoragePath(identifier: "evm")!
        let publicPath = PublicPath(identifier: "evm")!
        self.auth.storage.save<@EVM.CadenceOwnedAccount>(<-coa, to: storagePath)
        let addressableCap = self.auth.capabilities.storage.issue<&EVM.CadenceOwnedAccount>(storagePath)
        self.auth.capabilities.unpublish(publicPath)
        self.auth.capabilities.publish(addressableCap, at: publicPath)
    }
}
