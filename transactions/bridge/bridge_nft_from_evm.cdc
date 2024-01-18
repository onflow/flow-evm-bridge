import "FungibleToken"
import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FlowToken"
import "ExampleNFT"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeUtils"

transaction(nftTypeIdentifier: String, id: UInt256, collectionStoragePathIdentifier: String) {

    let evmContractAddress: EVM.EVMAddress
    let collection: &{NonFungibleToken.Collection}
    let tollFee: @FlowToken.Vault
    let coa: &EVM.BridgedAccount
    let calldata: [UInt8]
    
    prepare(signer: auth(BorrowValue) &Account) {
        let nftType: Type = CompositeType(nftTypeIdentifier) ?? panic("Could not construct NFT type")
        self.evmContractAddress = FlowEVMBridge.getAssetEVMContractAddress(type: nftType)
            ?? panic("EVM Contract address not found for given NFT type")

        let storagePath = StoragePath(identifier: collectionStoragePathIdentifier) ?? panic("Could not create storage path")
        self.collection = signer.storage.borrow<&{NonFungibleToken.Collection}>(from: storagePath)
            ?? panic("Could not borrow collection from storage path")

        let vault = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not access signer's FlowToken Vault")
        self.tollFee <- vault.withdraw(amount: FlowEVMBridge.fee) as! @FlowToken.Vault

        self.coa = signer.storage.borrow<&EVM.BridgedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        self.calldata = FlowEVMBridgeUtils.encodeABIWithSignature(
                "approve(address,uint256)",
                [FlowEVMBridge.getBridgeCOAEVMAddress(), id]
            )
    }

    execute {
        // Execute the bridge
        let nft: @{NonFungibleToken.NFT} <- FlowEVMBridge.bridgeNFTFromEVM(
            caller: self.coa,
            calldata: self.calldata,
            id: id,
            evmContractAddress: self.evmContractAddress,
            tollFee: <-self.tollFee
        )
        self.collection.deposit(token: <-nft)
    }

    // Post-assert bridge completed successfully
    post {
        self.collection.borrowNFT(
            FlowEVMBridgeUtils.uint256ToUInt64(value: id)
        ) != nil:
            "Problem bridging to signer's COA!"
    }
}