import "FungibleToken"
import "NonFungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// This transaction bridges an NFT from FlowEVM to Flow assuming it has already been onboarded to the FlowEVMBridge
/// NOTE: The ERC721 must have first been onboarded to the bridge. This can be checked via the method
///     FlowEVMBridge.evmAddressRequiresOnboarding(address: self.evmContractAddress) shown below
///
transaction(nftTypeIdentifier: String, id: UInt256, collectionStoragePathIdentifier: String) {

    let requiresOnboarding: Bool?
    let evmContractAddress: EVM.EVMAddress
    let collection: &{NonFungibleToken.Collection}
    let tollFee: @{FungibleToken.Vault}
    let coa: &EVM.BridgedAccount
    let calldata: [UInt8]
    
    prepare(signer: auth(BorrowValue) &Account) {

        // Get the ERC721 contract address for the given NFT type
        let nftType: Type = CompositeType(nftTypeIdentifier) ?? panic("Could not construct NFT type")
        self.evmContractAddress = FlowEVMBridge.getAssetEVMContractAddress(type: nftType)
            ?? panic("EVM Contract address not found for given NFT type")
        // Gather value to check before executing the bridge - added here for context
        self.requiresOnboarding = FlowEVMBridge.evmAddressRequiresOnboarding(address: self.evmContractAddress)

        // Borrow a reference to the NFT collection
        let storagePath = StoragePath(identifier: collectionStoragePathIdentifier) ?? panic("Could not create storage path")
        self.collection = signer.storage.borrow<&{NonFungibleToken.Collection}>(from: storagePath)
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

    // Assert the bridge is configured to bridge the requested NFT
    pre {
        self.requiresOnboarding != nil:
            "Requesting to bridge unsupported asset type"
        self.requiresOnboarding == false:
            "The requested NFT type has not yet been onboarded to the bridge"
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

    // Post-assert bridge completed successfully by checking the NFT resides in the Collection
    post {
        self.collection.borrowNFT(
            FlowEVMBridgeUtils.uint256ToUInt64(value: id)
        ) != nil:
            "Problem bridging to signer's COA!"
    }
}