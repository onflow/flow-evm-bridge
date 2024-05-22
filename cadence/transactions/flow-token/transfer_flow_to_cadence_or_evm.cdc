import "FungibleToken"
import "FlowToken"

import "EVM"

// Transfers $FLOW from the signer's account to the recipient's address, determining the target VM based on the format
// of the recipient's hex address.
///
/// @param addressString: The recipient's address in hex format - this should be either an EVM address or a Flow address
/// @param amount: The amount of $FLOW to transfer as a UFix64 value
///
transaction(addressString: String, amount: UFix64) {

    let sentVault: @FlowToken.Vault
    let evmRecipient: EVM.EVMAddress?
    var receiver: &{FungibleToken.Receiver}?
    
    prepare(signer: auth(BorrowValue, SaveValue) &Account) {
        // Reference signer's FlowToken Vault
        let sourceVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow signer's FlowToken.Vault")
        
        // Init receiver as nil
        self.receiver = nil
        // Ensure address is prefixed with '0x'
        let withPrefix = addressString.slice(from: 0, upTo: 2) == "0x" ? addressString : "0x".concat(addressString)
        // Attempt to parse address as Cadence or EVM address
        let cadenceRecipient = withPrefix.length < 40 ? Address.fromString(withPrefix) : nil
        self.evmRecipient = cadenceRecipient == nil ? EVM.addressFromString(withPrefix) : nil

        // Validate exactly one target address is assigned
        if cadenceRecipient != nil && self.evmRecipient != nil {
            panic("Malformed recipient address - assignable as both Cadence and EVM addresses")
        } else if cadenceRecipient == nil && self.evmRecipient == nil {
            panic("Malformed recipient address - not assignable as either Cadence or EVM address")
        }

        if cadenceRecipient != nil {
            // Assign FungibleToken Receiver if recipient is a Cadence address
            self.receiver = getAccount(cadenceRecipient!).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                ?? panic("Could not borrow FungibleToken Receiver from recipient")
        }

        // Create empty FLOW vault to capture funds
        self.sentVault <- sourceVault.withdraw(amount: amount) as! @FlowToken.Vault
    }

    pre {
        self.receiver != nil || self.evmRecipient != nil: "Could not assign a recipient for the transfer"
        self.sentVault.balance == amount: "Attempting to send an incorrect amount of $FLOW"
    }

    execute {
        // Complete Cadence transfer if the FungibleToken Receiver is assigned
        if self.receiver != nil {
            self.receiver!.deposit(from: <-self.sentVault)
        } else {
            // Otherwise, complete EVM transfer
            self.evmRecipient!.deposit(from: <-self.sentVault)
        }
    }
}
