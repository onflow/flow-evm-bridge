import "NonFungibleToken"

import "CrossVMNFT"

access(all)
fun main(ownerAddr: Address, cadenceID: UInt64, collectionStoragePath: StoragePath): UInt256? {
    if let collection = getAuthAccount<auth(BorrowValue) &Account>(ownerAddr).storage.borrow<&{NonFungibleToken.Collection}>(
            from: collectionStoragePath
        ) {
        if let nft = collection.borrowNFT(cadenceID) {
            return CrossVMNFT.getEVMID(from: nft)
        }
    }
    return nil
}
