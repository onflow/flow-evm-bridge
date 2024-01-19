import "FungibleToken"
import "FlowToken"

import "EVM"

/// Deploys a compiled solidity contract from bytecode to the EVM, with the signer's COA as the deployer
///
transaction(bytecode: String, gasLimit: UInt64, value: UFix64) {

    let bridgedAccount: &EVM.BridgedAccount
    var sentVault: @FlowToken.Vault?

    prepare(signer: auth(BorrowValue) &Account) {

        let storagePath = StoragePath(identifier: "evm")!
        self.bridgedAccount = signer.storage.borrow<&EVM.BridgedAccount>(from: storagePath)
            ?? panic("Could not borrow reference to the signer's bridged account")

        // Rebalance Flow across VMs if there is not enough Flow in the EVM account to cover the value
        let evmFlowBalance: UFix64 = self.bridgedAccount.balance().flow
        if self.bridgedAccount.balance().flow < value {
            let withdrawAmount: UFix64 = value - evmFlowBalance
            let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                    from: /storage/flowTokenVault
                ) ?? panic("Could not borrow reference to the owner's Vault!")

            self.sentVault <- vaultRef.withdraw(amount: withdrawAmount) as! @FlowToken.Vault
        } else {
            self.sentVault <- nil
        }
    }

    execute {

        // Deposit Flow into the EVM account if necessary otherwise destroy the sent Vault
        if self.sentVault != nil {
            self.bridgedAccount.address().deposit(from: <-self.sentVault!)
        } else {
            destroy self.sentVault
        }

        // Finally deploy the contract
        let address: EVM.EVMAddress = self.bridgedAccount.deploy(
           code: bytecode.decodeHex(),
           gasLimit: gasLimit,
           value: EVM.Balance(flow: value)
        )
    }
}
