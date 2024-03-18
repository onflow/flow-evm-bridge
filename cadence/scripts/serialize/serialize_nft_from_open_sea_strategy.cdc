import "ViewResolver"
import "MetadataViews"
import "NonFungibleToken"

import "SerializeNFT"

access(all)
fun main(address: Address, storagePathIdentifier: String, id: UInt64): String? {
    let storagePath = StoragePath(identifier: storagePathIdentifier)
        ?? panic("Could not construct StoragePath from identifier")
    if let collection = getAuthAccount<auth(BorrowValue) &Account>(address).storage
        .borrow<&{NonFungibleToken.Collection}>(
            from: storagePath
        ) {
        if let nft = collection.borrowNFT(id) {
            let strategy = SerializeNFT.OpenSeaMetadataSerializationStrategy()
            return strategy.serializeResource(nft)
        }
    }
    return nil
}
