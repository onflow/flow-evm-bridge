import "MetadataViews"

import "FlowEVMBridgeResolver"

/// This transaction sets the bridged NFT Display view for all NFTs bridged from Flow EVM
///
transaction(thumbnailURI: String, thumbnailFileTypeIdentifier: String, ipfsFilePath: String?) {

    let display: MetadataViews.Display
    let admin: auth(FlowEVMBridgeResolver.Metadata) &FlowEVMBridgeResolver.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        // Determine the intended File type based on the provided file type identifier
        let thumbnailFileType = CompositeType(thumbnailFileTypeIdentifier)
            ?? panic("Invalid file type identifier=".concat(thumbnailFileTypeIdentifier))
        // Build the thumbnail file
        let thumbnailFile = FlowEVMBridgeResolver.buildFile(
                uri: thumbnailURI,
                fileType: thumbnailFileType,
                ipfsFilePath: ipfsFilePath
            ) ?? panic("Failed to build thumbnail file")
        // Build the NFT Display view
        self.display = MetadataViews.Display(
                name: "This name is replaced by a bridged NFT's name",
                description: "This description is replaced by a bridged NFT's collection description",
                thumbnail: thumbnailFile
            )

        // Borrow the Admin resource
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeResolver.Metadata) &FlowEVMBridgeResolver.Admin>(
                from: FlowEVMBridgeResolver.AdminStoragePath
            ) ?? panic("Missing or mis-typed Admin resource")
    }

    execute {
        self.admin.setView(self.display)
    }
}