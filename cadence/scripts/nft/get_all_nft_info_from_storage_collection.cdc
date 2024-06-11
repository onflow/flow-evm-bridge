import "NonFungibleToken"
import "MetadataViews"

import "FlowEVMBridgeUtils"
import "CrossVMNFT"

/// Data structure to contain information about an NFT
///
access(all)
struct NFTInfo {
    access(all) let id: UInt64
    access(all) let name: String
    access(all) let symbol: String?
    access(all) let thumbnail: String?
    access(all) let uri: String?
    access(all) let collectionStoragePath: StoragePath
    access(all) let receiverPublicPath: PublicPath

    init(
        id: UInt64,
        name: String,
        symbol: String?,
        thumbnail: String,
        uri: String?,
        collectionStoragePath: StoragePath,
        receiverPublicPath: PublicPath
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.thumbnail = thumbnail
        self.uri = uri
        self.collectionStoragePath = collectionStoragePath
        self.receiverPublicPath = receiverPublicPath
    }
}

/// Retrieves the NFT info for all NFTs in a Collection
///
access(all)
fun getNFTInfoFromCollection(_ collection: &{NonFungibleToken.Collection}): {UInt64: NFTInfo}? {
    let res: {UInt64: NFTInfo} = {}
    let ids = collection.getIDs()
    // If empty, return early
    if ids.length == 0 {
        return res
    }

    for id in ids {
        let nft = collection.borrowNFT(id)
        if nft == nil {
            continue
        }

        let data = nft!.resolveView(Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
        let display = nft!.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?
        let bridged = nft!.resolveView(Type<MetadataViews.EVMBridgedMetadata>()) as! MetadataViews.EVMBridgedMetadata?

        // Skip if basic metadata is not available
        if data == nil || display == nil {
            continue
        }

        res.insert(
            key: id,
            NFTInfo(
                id: id,
                name: display!.name,
                symbol: bridged?.symbol,
                thumbnail: display!.thumbnail.uri(),
                uri: bridged?.uri?.uri(),
                collectionStoragePath: data!.storagePath,
                receiverPublicPath: data!.publicPath
            )
        )
    }

    return res
}

/// Retrieves the NFT info for all NFTs in a Collection at a given path
///
/// @param ownerAddress: The address of the account that owns the Collection
/// @param collectionPath: The path to the Collection
///
/// @return A dictionary of NFTInfo structs, keyed by the NFT ID
///
access(all)
fun main(ownerAddress: Address, collectionPath: StoragePath): {UInt64: NFTInfo}? {
    let account = getAuthAccount<auth(BorrowValue) &Account>(ownerAddress)
    let collection = account.storage.borrow<&{NonFungibleToken.Collection}>(from: collectionPath)
    
    return collection != nil ? getNFTInfoFromCollection(collection!) : nil
}