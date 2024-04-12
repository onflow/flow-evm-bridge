import "ViewResolver"
import "MetadataViews"
import "NonFungibleToken"

import "SerializeMetadata"

access(all)
fun main(address: Address, storagePathIdentifier: String, id: UInt64): String? {
    let storagePath = StoragePath(identifier: storagePathIdentifier)
        ?? panic("Could not construct StoragePath from identifier")
    if let collection = getAuthAccount<auth(BorrowValue) &Account>(address).storage
        .borrow<&{NonFungibleToken.Collection}>(
            from: storagePath
        ) {
        if let nft = collection.borrowNFT(id) {
            return SerializeMetadata.serializeNFTMetadataAsURI(nft)
        }
    }
    return nil
}
