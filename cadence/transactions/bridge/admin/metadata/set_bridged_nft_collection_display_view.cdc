import "MetadataViews"

import "FlowEVMBridgeResolver"

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
        // Build the square and banner image files
        let squareImageileType = CompositeType(squareImageFileTypeIdentifier)
            ?? panic("Invalid file type identifier=".concat(squareImageFileTypeIdentifier))
        let bannerImageFileType = CompositeType(bannerImageFileTypeIdentifier)
            ?? panic("Invalid file type identifier=".concat(bannerImageFileTypeIdentifier))
        let squareImageFile = FlowEVMBridgeResolver.buildFile(
                uri: squareImageURI,
                fileType: squareImageileType,
                ipfsFilePath: squareImageIPFSFilePath
            ) ?? panic("Failed to build square image file")
        let bannerImageFile = FlowEVMBridgeResolver.buildFile(
                uri: bannerImageURI,
                fileType: bannerImageFileType,
                ipfsFilePath: bannerImageIPFSFilePath
            ) ?? panic("Failed to build banner image file")
        // Build the socials dictionary
        let socials = FlowEVMBridgeResolver.buildExternalURLMapping(fromDict: socialsDict)
        // Build the NFTCollectionDisplay view
        self.nftCollectionDisplay = MetadataViews.NFTCollectionDisplay(
                name: "This name is replaced by a bridged NFT's collection name",
                description: "This description is replaced by a bridged NFT's collection description",
                externalURL: MetadataViews.ExternalURL(externalURL),
                squareImage: MetadataViews.Media(file: squareImageFile, mediaType: squareImageMediaType),
                bannerImage: MetadataViews.Media(file: bannerImageFile, mediaType: squareImageMediaType),
                socials: socials
            )

        // Borrow the Admin resource
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeResolver.Metadata) &FlowEVMBridgeResolver.Admin>(
                from: FlowEVMBridgeResolver.AdminStoragePath
            ) ?? panic("Missing or mis-typed Admin resource")
    }

    execute {
        self.admin.setView(self.nftCollectionDisplay)
    }
}