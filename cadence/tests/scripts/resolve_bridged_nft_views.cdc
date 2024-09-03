import "MetadataViews"
import "NonFungibleToken"

access(all)
fun main(address: Address, collectionPathIdentifier: String, id: UInt64): Bool {
    let path = StoragePath(identifier: collectionPathIdentifier) ?? panic("Malformed StoragePath identifier")
    if let collection = getAuthAccount<auth(BorrowValue) &Account>(address).storage.borrow<&{NonFungibleToken.Collection}>(
            from: path
        ) {
        if let nft = collection.borrowNFT(id) {
            let display = nft.resolveView(Type<MetadataViews.Display>()) ?? panic("Display was not resolved")
            let collectionDisplay = nft.resolveView(Type<MetadataViews.NFTCollectionDisplay>()) ?? panic("NFTCollectionDisplay was not resolved")
            return true
        }
    }
    return false
}
