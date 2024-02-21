import "FungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridgeUtils"

/// Transfers $FLOW from the signer's account Cadence Flow balance to the recipient's hex-encoded EVM address.
/// Note that a COA must have a $FLOW balance in EVM before transferring value to another EVM address.
///
transaction(recipientEVMAddressHex: String, amount: UFix64, gasLimit: UInt64) {

    let coa: &EVM.BridgedAccount
    let recipientEVMAddress: EVM.EVMAddress
    var sentVault: @FlowToken.Vault

    prepare(signer: auth(BorrowValue, SaveValue) &Account) {
        if signer.storage.type(at: /storage/evm) == nil {
            signer.storage.save(<-EVM.createBridgedAccount(), to: /storage/evm)
        }
        self.coa = signer.storage.borrow<&EVM.BridgedAccount>(from: /storage/evm)
            ?? panic("Could not borrow reference to the signer's bridged account")

        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not borrow reference to the owner's Vault!")
        self.sentVault <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault

        self.recipientEVMAddress = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: recipientEVMAddressHex)
            ?? panic("Invalid recipient EVM address")
    }

    execute {
        self.coa.deposit(from: <-self.sentVault)
        if self.recipientEVMAddress.bytes == self.coa.address().bytes {
            return
        }
        self.coa.call(
            to: self.recipientEVMAddress,
            data: [],
            gasLimit: gasLimit,
            value: EVM.Balance(flow: amount)
        )
    }
}
