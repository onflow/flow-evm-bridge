import "FungibleToken"
import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FlowToken"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// This transaction bridges an NFT from FlowEVM to Flow assuming it has already been onboarded to the FlowEVMBridge
/// NOTE: The ERC721 must have first been onboarded to the bridge. This can be checked via the method
///     FlowEVMBridge.evmAddressRequiresOnboarding(address: self.evmContractAddress)
///
transaction(nftContractAddress: Address, nftContractName: String, id: UInt256) {

    let evmContractAddress: EVM.EVMAddress
    let collection: &{NonFungibleToken.Collection}
    let tollFee: @{FungibleToken.Vault}
    let coa: &EVM.BridgedAccount
    let calldata: [UInt8]
    
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {

        // Get the ERC721 contract address for the given NFT type
        let nftType = FlowEVMBridgeUtils.buildCompositeType(
                address: nftContractAddress,
                contractName: nftContractName,
                resourceName: "NFT"
            ) ?? panic("Could not construct NFT type")
        self.evmContractAddress = FlowEVMBridge.getAssetEVMContractAddress(type: nftType)
            ?? panic("EVM Contract address not found for given NFT type")

        // Borrow a reference to the NFT collection, configuring if necessary
        let viewResolver = getAccount(nftContractAddress).contracts.borrow<&ViewResolver>(name: nftContractName)
            ?? panic("Could not borrow ViewResolver from NFT contract")
        let collectionData = viewResolver.resolveView(Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not resolve NFTCollectionData view")
        if signer.storage.borrow<&{NonFungibleToken.Collection}>(from: collectionData.storagePath) == nil {
            signer.storage.save(<-collectionData.createEmptyCollection(), to: collectionData.storagePath)
            signer.capabilities.unpublish(collectionData.publicPath)
            let collectionCap = signer.capabilities.storage.issue<&{NonFungibleToken.Collection}>(collectionData.storagePath)
            signer.capabilities.publish(collectionCap, at: collectionData.publicPath)
        }
        self.collection = signer.storage.borrow<&{NonFungibleToken.Collection}>(from: collectionData.storagePath)
            ?? panic("Could not borrow collection from storage path")

        // Get the funds to pay the bridging fee from the signer's FlowToken Vault
        let vault = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not access signer's FlowToken Vault")
        self.tollFee <- vault.withdraw(amount: FlowEVMBridgeConfig.fee)

        // Borrow a reference to the signer's COA
        // NOTE: This should also be the ERC721 owner of the requested NFT in FlowEVM
        self.coa = signer.storage.borrow<&EVM.BridgedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        // Encode the approve calldata, approving the Bridge COA to act on the NFT
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
        // Deposit the bridged NFT into the signer's collection
        self.collection.deposit(token: <-nft)
    }
}
