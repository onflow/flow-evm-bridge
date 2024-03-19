import "NonFungibleToken"

/// Returns the IDs of all the NFTs in a collection
///
/// @param address: The address of the account that owns the collection
/// @param collectionPathIdentifier: The identifier of the collection's storage path
///
/// @returns An array of the UInt64 IDs of all the NFTs in the collection or nil if the account is not configured
///     with a Collection at the given path
///
access(all) fun main(address: Address, collectionPathIdentifier: String): [UInt64]? {
    let path = StoragePath(identifier: collectionPathIdentifier) ?? panic("Malformed StoragePath identifier")
    return getAuthAccount<auth(BorrowValue) &Account>(address).storage.borrow<&{NonFungibleToken.Collection}>(
            from: path
        )?.getIDs()
        ?? nil
}
