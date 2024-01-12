import "FungibleToken"
import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FlowToken"
import "ExampleNFT"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeUtils"

// PROTO: id: 17509995351216488448 | collectionStoragePathIdentifier: "cadenceExampleNFTCollection"
transaction(id: UInt64, collectionStoragePathIdentifier: String) {
    
    let nft: @{NonFungibleToken.NFT}
    let nftType: Type
    let evmRecipient: EVM.EVMAddress
    // let evmContractAddress: EVM.EVMAddress
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
        self.evmRecipient = signer.storage.borrow<&EVM.BridgedAccount>(from: /storage/evm)!.address()
        // Pay the bridge toll
        let vault = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not access signer's FlowToken Vault")
        self.tollFee <- vault.withdraw(amount: FlowEVMBridge.fee) as! @FlowToken.Vault
        self.success = false
    }

    execute {
        // Execute the bridge
        FlowEVMBridge.bridgeNFTToEVM(token: <-self.nft, to: self.evmRecipient, tollFee: <-self.tollFee)
        // TODO: Impl FlowEVMBridge.getAssetEVMContractAddress
        // self.success = FlowEVMBridgeUtils.isOwnerOrApproved(
        //     ofNFT: UInt256(id),
        //     owner: self.evmRecipient.address(),
        //     evmContractAddress: FlowEVMBridge.getAssetEVMContractAddress(forType: nftType)
        // )
    }

    // Post-assert bridge completed successfully on EVM side
    // TODO
    // post {
    //     self.success: "Problem bridging to signer's COA!"
    // }
}