import "EVM"
import "FungibleToken"
import "FlowToken"

transaction(bytecode: String, gasLimit: UInt64, bridgeFlow: UFix64) {
    let sentVault: @FlowToken.Vault?

    prepare(signer: auth(BorrowValue) &Account) {
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not borrow reference to the owner's Vault!")

        self.sentVault <- vaultRef.withdraw(amount: bridgeFlow) as! @FlowToken.Vault
    }

    execute {
        let decodedCode = bytecode.decodeHex()

        let bridgedAccount <- EVM.createBridgedAccount()
        bridgedAccount.address().deposit(from: <-self.sentVault)

        let address = bridgedAccount.deploy(
           code: decodedCode,
           gasLimit: 300000,
           value: EVM.Balance(flow: 0.5)
        )

        destroy bridgedAccount
    }
}