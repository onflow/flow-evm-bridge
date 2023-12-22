import "EVM"
import "FungibleToken"
import "FlowToken"

transaction(bytecode: String, gasLimit: UInt64) {
    let sentVault: @FlowToken.Vault

    prepare(signer: AuthAccount) {
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.sentVault <- vaultRef.withdraw(amount: 1.0) as! @FlowToken.Vault
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