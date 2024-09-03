import "MetadataViews"

import "FlowEVMBridgeResolver"

/// Builds a thumbnail file based on the provided thumbnail file type identifier and optional IPFS file path
///
access(all)
fun buildFile(_ uri: String, _ fileTypeIdentifier: String, _ ipfsFilePath: String?): {MetadataViews.File} {
    // Determine the inteded File type based on the provided file type identifier
    let thumbnailFileType = CompositeType(fileTypeIdentifier)
        ?? panic("Invalid file type identifier=".concat(fileTypeIdentifier))
    
    // Build the thumbnail file based on the determined file type
    if thumbnailFileType == Type<MetadataViews.HTTPFile>() {
        return MetadataViews.HTTPFile(url: uri)
    } else if thumbnailFileType == Type<MetadataViews.IPFSFile>() {
        return MetadataViews.IPFSFile(cid: uri, path: ipfsFilePath)
    } else {
        panic("Unsupported file type=".concat(fileTypeIdentifier))
    }
}

/// Builds a socials dictionary based on the provided socials dictionary as a string to string mapping
///
access(all)
fun buildSocials(_ socials: {String: String}): {String: MetadataViews.ExternalURL} {
    let res: {String: MetadataViews.ExternalURL} = {}
    socials.forEachKey(fun (key: String): Bool {
        res[key] = MetadataViews.ExternalURL(socials[key]!)
        return true
    })
    return res
}

/// This transaction sets the bridged NFTCollectionDisplay view for all NFTs bridged from Flow EVM
///
transaction(
    externalURL: String,
    squareImageURI: String,
    squareImageFileTypeIdentifier: String,
    squareImageIPFSFilePath: String?,
    squareImageMediaType: String,
    bannerImageURI: String,
    bannerImageFileTypeIdentifier: String,
    bannerImageIPFSFilePath: String?,
    bannerImageMediaType: String,
    socialsDict: {String: String}
) {

    let nftCollectionDisplay: MetadataViews.NFTCollectionDisplay
    let admin: auth(FlowEVMBridgeResolver.Metadata) &FlowEVMBridgeResolver.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        let squareImage = MetadataViews.Media(
                file: buildFile(squareImageURI, squareImageFileTypeIdentifier, squareImageIPFSFilePath),
                mediaType: squareImageMediaType
            )
        let bannerImage = MetadataViews.Media(
                file: buildFile(bannerImageURI, bannerImageFileTypeIdentifier, bannerImageIPFSFilePath),
                mediaType: bannerImageMediaType
            )
        let socials = buildSocials(socialsDict)
        self.nftCollectionDisplay = MetadataViews.NFTCollectionDisplay(
                name: "This name is replaced by a bridged NFT's collection name",
                description: "This description is replaced by a bridged NFT's collection description",
                externalURL: MetadataViews.ExternalURL(externalURL),
                squareImage: squareImage,
                bannerImage: bannerImage,
                socials: socials
            )

        self.admin = signer.storage.borrow<auth(FlowEVMBridgeResolver.Metadata) &FlowEVMBridgeResolver.Admin>(
                from: FlowEVMBridgeResolver.AdminStoragePath
            ) ?? panic("Missing or mis-typed Admin resource")
    }

    execute {
        self.admin.setView(self.nftCollectionDisplay)
    }
}