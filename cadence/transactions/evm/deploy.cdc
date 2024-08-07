import "FungibleToken"
import "FlowToken"

import "EVM"

/// Deploys a compiled solidity contract from bytecode to the EVM, with the signer's COA as the deployer
///
transaction(bytecode: String, gasLimit: UInt64, value: UFix64) {

    let coa: auth(EVM.Deploy) &EVM.CadenceOwnedAccount
    var sentVault: @FlowToken.Vault?

    prepare(signer: auth(BorrowValue) &Account) {

        let storagePath = StoragePath(identifier: "evm")!
        self.coa = signer.storage.borrow<auth(EVM.Deploy) &EVM.CadenceOwnedAccount>(from: storagePath)
            ?? panic("Could not borrow reference to the signer's bridged account")

        // Rebalance Flow across VMs if there is not enough Flow in the EVM account to cover the value
        let evmFlowBalance: UFix64 = self.coa.balance().inFLOW()
        if self.coa.balance().inFLOW() < value {
            let withdrawAmount: UFix64 = value - evmFlowBalance
            let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
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
            self.coa.deposit(from: <-self.sentVault!)
        } else {
            destroy self.sentVault
        }

        let valueBalance = EVM.Balance(attoflow: 0)
        valueBalance.setFLOW(flow: value)
        // Finally deploy the contract
        let evmResult = self.coa.deploy(
           code: bytecode.decodeHex(),
           gasLimit: gasLimit,
           value: valueBalance
        )
        assert(
            evmResult.status == EVM.Status.successful && evmResult.deployedContract != nil,
            message: "EVM deployment failed with error code: ".concat(evmResult.errorCode.toString())
        )
    }
}
