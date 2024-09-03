import "MetadataViews"
import "FungibleTokenMetadataViews"

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

access(all)
fun buildSocials(_ socials: {String: String}): {String: MetadataViews.ExternalURL} {
    let res: {String: MetadataViews.ExternalURL} = {}
    socials.forEachKey(fun (key: String): Bool {
        res[key] = MetadataViews.ExternalURL(socials[key]!)
        return true
    })
    return res
}

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
        let logo = MetadataViews.Media(
                file: buildFile(logoURI, logoFileTypeIdentifier, logoIPFSFilePath),
                mediaType: logoMediaType
            )
        let logos = MetadataViews.Medias([logo])
        let socials = buildSocials(socialsDict)
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