import "FungibleToken"
import "FlowToken"

import "EVM"

/// This transactions wraps FLOW tokens as WFLOW tokens, using the signing COA's EVM FLOW balance primarily. If the 
/// EVM balance is insufficient, the transaction will transfer FLOW from the Cadence balance to the EVM balance.
///
/// @param wflowContractHex: The EVM address of the WFLOW contract as a hex string
/// @param amount: The amount of FLOW to wrap as WFLOW
///
transaction(wflowContractHex: String, amount: UFix64) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    let vault: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        self.vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("Missing FLOW vault")
    }

    execute {
        // Transfer from Cadence balance to EVM balance if EVM balance is insufficient
        let evmBalance = self.coa.balance().inFLOW()
        if evmBalance < amount {
            let fundVault <- self.vault.withdraw(amount: amount - evmBalance) as! @FlowToken.Vault
            self.coa.deposit(from: <-fundVault)
        }
        // Define the value to send to the WFLOW contract
        let balance = EVM.Balance(attoflow: 0)
        balance.setFLOW(flow: amount)
        let calldata = EVM.encodeABIWithSignature("deposit()", [])
        let result = self.coa.call(
            to: EVM.addressFromString(wflowContractHex),
            data: calldata,
            gasLimit: 15_000_000,
            value: balance
        )
        assert(result.status == EVM.Status.successful, message: "Failed to wrap FLOW as WFLOW")
    }
}
