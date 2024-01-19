import "FungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridgeUtils"

/// Transfers $FLOW from the signer's account Cadence Flow balance to the recipient's hex-encoded EVM address
///
transaction(amount: UFix64, recipientEVMAddressHex: String) {

    let sender: &EVM.BridgedAccount
    let recipientEVMAddress: EVM.EVMAddress
    var sentVault: @FlowToken.Vault?

    prepare(signer: auth(BorrowValue) &Account) {

        let storagePath = StoragePath(identifier: "evm")!
        self.sender = signer.storage.borrow<&EVM.BridgedAccount>(from: storagePath)
            ?? panic("Could not borrow reference to the signer's bridged account")

        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not borrow reference to the owner's Vault!")
        self.sentVault <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault

        if recipientEVMAddressHex == nil {
            self.recipientEVMAddress = self.sender.address()
        } else {
            self.recipientEVMAddress = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: recipientEVMAddressHex!)
                ?? panic("Invalid recipient EVM address")
        }
    }

    execute {
        self.recipientEVMAddress.deposit(from: <-self.sentVault!)
    }
}
