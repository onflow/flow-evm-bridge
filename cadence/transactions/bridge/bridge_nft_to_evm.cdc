import "FungibleToken"
import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FlowToken"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// Bridges an NFT from the signer's collection in Flow to the recipient in FlowEVM
/// NOTE: The NFT being bridged must have first been onboarded by type. This can be checked for with the method
///     FlowEVMBridge.typeRequiresOnboarding(type): Bool?
///
transaction(nftContractAddress: Address, nftContractName: String, id: UInt64, recipient: String) {
    
    let nft: @{NonFungibleToken.NFT}
    let nftType: Type
    let coa: auth(EVM.Bridge) &EVM.CadenceOwnedAccount
    let evmRecipient: EVM.EVMAddress
    let tollFee: @FlowToken.Vault
    let vault: auth(FungibleToken.Withdraw) &FlowToken.Vault
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow a reference to the NFT collection, configuring if necessary
        let viewResolver = getAccount(nftContractAddress).contracts.borrow<&{ViewResolver}>(name: nftContractName)
            ?? panic("Could not borrow ViewResolver from NFT contract")
        let collectionData = viewResolver.resolveContractView(
                resourceType: nil,
                viewType: Type<MetadataViews.NFTCollectionData>()
            ) as! MetadataViews.NFTCollectionData? ?? panic("Could not resolve NFTCollectionData view")
        // Withdraw the requested NFT
        let collection = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(
                from: collectionData.storagePath
            ) ?? panic("Could not access signer's NFT Collection")
        self.nft <- collection.withdraw(withdrawID: id)
        // Save the type for our post-assertion
        self.nftType = self.nft.getType()
        // Assign the recipient EVMAddress
        self.evmRecipient = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: recipient)
            ?? panic("Malformed Recipient Address")
        // Pay the bridge toll
        self.vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not access signer's FlowToken Vault")
        self.tollFee <- self.vault.withdraw(amount: FlowEVMBridgeConfig.bridgeFee) as! @FlowToken.Vault
        // Borrow a reference to the signer's COA
        self.coa = signer.storage.borrow<auth(EVM.Bridge) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        // Execute the bridge
        let surplusFee <- self.coa.depositNFT(nft: <-self.nft, fee: <-self.tollFee)
        self.vault.deposit(from: <-surplusFee)
    }
}
