import "MetadataViews"
import "FungibleTokenMetadataViews"

import "FlowEVMBridgeResolver"

/// This transaction sets the bridged FTDisplay view for all fungible tokens bridged from Flow EVM
///
transaction(
    externalURL: String,
    logoURI: String,
    logoFileTypeIdentifier: String,
    logoIPFSFilePath: String?,
    logoMediaType: String,
    socialsDict: {String: String}
) {

    let ftDisplay: FungibleTokenMetadataViews.FTDisplay
    let admin: auth(FlowEVMBridgeResolver.Metadata) &FlowEVMBridgeResolver.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        // Determine the inteded File type based on the provided file type identifier
        let fileType = CompositeType(logoFileTypeIdentifier)
            ?? panic("Invalid file type identifier=".concat(logoFileTypeIdentifier))
        let file = FlowEVMBridgeResolver.buildFile(
                uri: logoURI,
                fileType: fileType,
                ipfsFilePath: logoIPFSFilePath
            ) ?? panic("Failed to build file")
        let logo = MetadataViews.Media(
                file: file,
                mediaType: logoMediaType
            )
        let logos = MetadataViews.Medias([logo])
        let socials = FlowEVMBridgeResolver.buildExternalURLMapping(fromDict: socialsDict)
        self.ftDisplay = FungibleTokenMetadataViews.FTDisplay(
                name: "This name is replaced by a bridged token's name",
                symbol: "This symbol is replaced by a bridged token's symbol",
                description: "This description is replaced by a bridged token's description",
                externalURL: MetadataViews.ExternalURL(externalURL),
                logos: logos,
                socials: socials
            )

        self.admin = signer.storage.borrow<auth(FlowEVMBridgeResolver.Metadata) &FlowEVMBridgeResolver.Admin>(
                from: FlowEVMBridgeResolver.AdminStoragePath
            ) ?? panic("Missing or mis-typed Admin resource")
    }

    execute {
        self.admin.setView(self.ftDisplay)
    }
}