/// This script uses the NFTMinter resource to mint a new NFT
/// It must be run with the account that has the minter resource
/// stored in /storage/NFTMinter

import "NonFungibleToken"
import "ExampleCadenceNativeNFT"
import "MetadataViews"
import "FungibleToken"

transaction(
    recipient: Address,
    name: String,
    description: String
) {

    /// local variable for storing the minter reference
    let minter: &ExampleCadenceNativeNFT.NFTMinter

    /// Reference to the receiver's collection
    let recipientCollectionRef: &{NonFungibleToken.Collection}

    prepare(signer: auth(BorrowValue) &Account) {

        let collectionData = ExampleCadenceNativeNFT.resolveContractView(
                resourceType: nil,
                viewType: Type<MetadataViews.NFTCollectionData>()
            ) as! MetadataViews.NFTCollectionData?
            ?? panic("ViewResolver does not resolve NFTCollectionData view")

        // borrow a reference to the NFTMinter resource in storage
        self.minter = signer.storage.borrow<&ExampleCadenceNativeNFT.NFTMinter>(from: ExampleCadenceNativeNFT.MinterStoragePath)
            ?? panic("Account does not store an object at the specified path")

        // Borrow the recipient's public NFT collection reference
        self.recipientCollectionRef = getAccount(recipient).capabilities.borrow<&{NonFungibleToken.Collection}>(
                collectionData.publicPath
            ) ?? panic("Could not get receiver reference to the NFT Collection")
    }

    execute {
        // Mint the NFT and deposit it to the recipient's collection
        self.minter.mintNFT(name: name, description: description, to: self.recipientCollectionRef)
    }

}