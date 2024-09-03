import "MetadataViews"

import "FlowEVMBridgeResolver"

/// Builds a thumbnail file based on the provided thumbnail file type identifier and optional IPFS file path
///
access(all)
fun buildThumbnailFile(_ thumbnailURI: String, _ thumbnailFileTypeIdentifier: String, _ ipfsFilePath: String?): {MetadataViews.File} {
    // Determine the inteded File type based on the provided file type identifier
    let thumbnailFileType = CompositeType(thumbnailFileTypeIdentifier)
        ?? panic("Invalid file type identifier=".concat(thumbnailFileTypeIdentifier))
    
    // Build the thumbnail file based on the determined file type
    if thumbnailFileType == Type<MetadataViews.HTTPFile>() {
        return MetadataViews.HTTPFile(url: thumbnailURI)
    } else if thumbnailFileType == Type<MetadataViews.IPFSFile>() {
        return MetadataViews.IPFSFile(cid: thumbnailURI, path: ipfsFilePath)
    } else {
        panic("Unsupported file type=".concat(thumbnailFileTypeIdentifier))
    }
}

/// This transaction sets the bridged NFT Display view for all NFTs bridged from Flow EVM
///
transaction(thumbnailURI: String, thumbnailFileTypeIdentifier: String, ipfsFilePath: String?) {

    let display: MetadataViews.Display
    let admin: auth(FlowEVMBridgeResolver.Metadata) &FlowEVMBridgeResolver.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        let thumbnailFile = buildThumbnailFile(thumbnailURI, thumbnailFileTypeIdentifier, ipfsFilePath)
        self.display = MetadataViews.Display(
                name: "This name is replaced by a bridged NFT's name",
                description: "This description is replaced by a bridged NFT's collection description",
                thumbnail: thumbnailFile
            )

        self.admin = signer.storage.borrow<auth(FlowEVMBridgeResolver.Metadata) &FlowEVMBridgeResolver.Admin>(
                from: FlowEVMBridgeResolver.AdminStoragePath
            ) ?? panic("Missing or mis-typed Admin resource")
    }

    execute {
        self.admin.setView(self.display)
    }
}