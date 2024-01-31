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

/// Bridges an NFT from the signer's collection in Flow to the recipient in FlowEVM
/// NOTE: The NFT being bridged must have first been onboarded by type. This can be checked for with the method
///     FlowEVMBridge.typeRequiresOnboarding(type): Bool? - see the pre-condition below
///
transaction(id: UInt64, collectionStoragePathIdentifier: String, recipient: String) {
    
    let nft: @{NonFungibleToken.NFT}
    let nftType: Type
    let evmRecipient: EVM.EVMAddress
    let tollFee: @{FungibleToken.Vault}
    var success: Bool
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Withdraw the requested NFT
        let collection = signer.storage.borrow<auth(NonFungibleToken.Withdrawable) &{NonFungibleToken.Collection}>(
                from: StoragePath(identifier: collectionStoragePathIdentifier) ?? panic("Could not create storage path")
            )!
        self.nft <- collection.withdraw(withdrawID: id)
        // Save the type for our post-assertion
        self.nftType = self.nft.getType()
        // Assign the recipient EVMAddress
        self.evmRecipient = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: recipient)
            ?? panic("Malformed Recipient Address")
        // Pay the bridge toll
        let vault = signer.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not access signer's FlowToken Vault")
        self.tollFee <- vault.withdraw(amount: FlowEVMBridgeConfig.fee)
        self.success = false
    }

    // Check that the type has been onboarded to the bridge - checked in the bridge contract, added here for context
    pre {
        FlowEVMBridge.typeRequiresOnboarding(self.nftType) != nil:
            "Requesting to bridge unsupported asset type"
        FlowEVMBridge.typeRequiresOnboarding(self.nftType) == false:
            "The requested NFT type has not yet been onboarded to the bridge"
    }

    execute {
        // Execute the bridge
        FlowEVMBridge.bridgeNFTToEVM(token: <-self.nft, to: self.evmRecipient, tollFee: <-self.tollFee)

        // Ensure the intended recipient is the owner of the NFT we bridged
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