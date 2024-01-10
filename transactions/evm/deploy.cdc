import "FungibleToken"
import "FlowToken"

import "EVM"

transaction(bytecode: String, gasLimit: UInt64, bridgeFlow: UFix64) {
    let sentVault: @FlowToken.Vault
    let bridgedAccount: &EVM.BridgedAccount

    prepare(signer: auth(BorrowValue) &Account) {
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not borrow reference to the owner's Vault!")

        self.sentVault <- vaultRef.withdraw(amount: bridgeFlow) as! @FlowToken.Vault

        // Reference the signer's BridgedAccount
        let storagePath = StoragePath(identifier: "evm")!
        self.bridgedAccount = signer.storage.borrow<&EVM.BridgedAccount>(from: storagePath)
            ?? panic("Could not borrow reference to the signer's bridged account")
    }

    execute {
        let decodedCode = bytecode.decodeHex()

        self.bridgedAccount.address().deposit(from: <-self.sentVault)

        let address = self.bridgedAccount.deploy(
           code: decodedCode,
           gasLimit: gasLimit,
           value: EVM.Balance(flow: bridgeFlow)
        )
    }
}
