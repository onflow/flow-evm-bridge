import "FungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeUtils"
import "FlowEVMBridgeConfig"

/// This transaction onboards the NFT type to the bridge, configuring the bridge to move NFTs between environments
/// NOTE: This must be done before bridging a Flow-native NFT to Flow EVM
///
transaction(contractAddressHex: String) {

    let contractAddress: EVM.EVMAddress
    let tollFee: @{FungibleToken.Vault}
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Construct the type from the identifier
        self.contractAddress = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: contractAddressHex)
            ?? panic("Invalid EVM address string provided")
        // Pay the bridge toll
        let vault = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not access signer's FlowToken Vault")
        self.tollFee <- vault.withdraw(amount: FlowEVMBridgeConfig.fee)
    }

    execute {
        // Onboard the NFT Type
        FlowEVMBridge.onboardByEVMAddress(self.contractAddress, tollFee: <-self.tollFee)
    }
}
