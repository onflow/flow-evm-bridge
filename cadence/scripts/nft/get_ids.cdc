import "NonFungibleToken"

access(all) fun main(address: Address, collectionPathIdentifier: String): [UInt64] {
    let path = StoragePath(identifier: collectionPathIdentifier) ?? panic("Malformed StoragePath identifier")
    return getAuthAccount<auth(BorrowValue) &Account>(address).storage.borrow<&{NonFungibleToken.Collection}>(
            from: path
        )?.getIDs()
        ?? panic("Collection not found")
}
