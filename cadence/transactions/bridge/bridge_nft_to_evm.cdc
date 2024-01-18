import "FungibleToken"
import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FlowToken"
import "ExampleNFT"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

// TODO: Try a simple NFT contract & interact via COA to confirm they can receive NFTs
transaction(id: UInt64, collectionStoragePathIdentifier: String, recipient: String) {
    
    let nft: @{NonFungibleToken.NFT}
    let nftType: Type
    let evmRecipient: EVM.EVMAddress
    let tollFee: @FlowToken.Vault
    var success: Bool
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Withdraw the requested NFT
        let collection = signer.storage.borrow<auth(NonFungibleToken.Withdrawable) &{NonFungibleToken.Collection}>(
                from: StoragePath(identifier: collectionStoragePathIdentifier) ?? panic("Could not create storage path")
            )!
        self.nft <- collection.withdraw(withdrawID: id)
        // Save the type for our post-assertion
        self.nftType = self.nft.getType()
        // Get the signer's COA EVMAddress as recipient
        if recipient == nil {
            self.evmRecipient = signer.storage.borrow<&EVM.BridgedAccount>(from: /storage/evm)!.address()
        } else {
            self.evmRecipient = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: recipient!)
                ?? panic("Malformed Recipient Address")
        }
        // Pay the bridge toll
        let vault = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not access signer's FlowToken Vault")
        self.tollFee <- vault.withdraw(amount: FlowEVMBridgeConfig.fee) as! @FlowToken.Vault
        self.success = false
    }

    execute {
        // Execute the bridge
        FlowEVMBridge.bridgeNFTToEVM(token: <-self.nft, to: self.evmRecipient, tollFee: <-self.tollFee)
        self.success = FlowEVMBridgeUtils.isOwnerOrApproved(
            ofNFT: UInt256(id),
            owner: self.evmRecipient,
            evmContractAddress: FlowEVMBridge.getAssetEVMContractAddress(type: self.nftType) ?? panic("No EVM Address found for NFT type")
        )
    }

    // Post-assert bridge completed successfully on EVM side
    post {
        self.success: "Problem bridging to signer's COA!"
    }
}