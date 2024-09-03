import "MetadataViews"
import "FungibleTokenMetadataViews"
import "FungibleToken"
import "NonFungibleToken"

import "ICrossVMAsset"
import "CrossVMToken"
import "CrossVMNFT"
import "FlowEVMBridgeUtils"

/// This contract serves as a metadata resolver for shared views on NFTs and FungibleTokens bridged from EVM to Cadence.
/// Upon bridging to Cadence, these tokens must have certain basic metadata views that cannot be retrieved at the time
/// of bridging, such as MetadataViews.Display for NFTs and FungibleTokenMetadataViews.FTDisplay for FungibleTokens.
///
/// This contract then serves as a means of setting and potentially updating base placeholder views for these bridged
/// assets. Anyone wishing to consume the metadata from the source EVM contract should either resolve directly from the
/// EVM contract or leverage the EVMBridgedMetadata view which retains the original token URI and/or contract URI (if
/// implemented in the source contract).
///
access(all) contract FlowEVMBridgeResolver {

    /******************
        Entitlements
    *******************/

    access(all) entitlement Metadata

    /*************
        Fields
    **************/

    /// The views managed by this contract, indexed on the view type
    access(all) let views: {Type: AnyStruct}

    /********************
        Path Constants
    *********************/

    /// The default storage path of the Admin resource
    access(all) let AdminStoragePath: StoragePath

    /*************
        Events
    **************/

    /// Emitted when a view is added, removed, or updated.
    /// added == true -> new | added == false -> removed | added == nil -> updated
    access(all) event ViewUpdated(viewType: String, added: Bool?)

    /*************
        Getters
     *************/

    /// Getter for bridged NFT views.
    ///
    /// @param forNFT: The bridged NFT
    /// @param view: The view type to resolve
    ///
    /// @returns The resolved view or nil if the view type is not supported
    ///
    access(all)
    fun resolveBridgedView(bridgedContract: &{ICrossVMAsset}, view: Type): AnyStruct? {
        /// Return nil if the resource is not defined by a bridge contract
        let contractAddressString = bridgedContract.getType().identifier.split(separator: ".")[1]
        let contractAddress = Address.fromString("0x".concat(contractAddressString))
        if contractAddress != self.account.address {
            return nil
        }
        // Handle based on whether the contract defines a bridged NFT or FungibleToken
        if let crossVMNFT = bridgedContract as? &{ICrossVMAsset, NonFungibleToken} {
            // Dealing with a bridged NFT, continue
            switch view {
                case Type<MetadataViews.Display>():
                    if let baseDisplay = self.views[Type<MetadataViews.Display>()] as! MetadataViews.Display? {
                        return MetadataViews.Display(
                            name: crossVMNFT.getName(),
                            description: "This NFT was bridged from EVM on Flow with the ERC721 contract address of "
                                .concat(crossVMNFT.getEVMContractAddress().toString()),
                            thumbnail: baseDisplay.thumbnail
                        )
                    }
                case Type<MetadataViews.NFTCollectionDisplay>():
                    if let baseCollectionDisplay = self.views[Type<MetadataViews.NFTCollectionDisplay>()] as! MetadataViews.NFTCollectionDisplay? {
                        return MetadataViews.NFTCollectionDisplay(
                            name: crossVMNFT.getName(),
                            description: "This NFT Collection was bridged from EVM on Flow with the ERC721 contract address of "
                                .concat(crossVMNFT.getEVMContractAddress().toString()),
                            externalURL: baseCollectionDisplay.externalURL,
                            squareImage: baseCollectionDisplay.squareImage,
                            bannerImage: baseCollectionDisplay.bannerImage,
                            socials: baseCollectionDisplay.socials
                        )
                    }
            }
            return nil
        } else if let crossVMToken = bridgedContract as? &{ICrossVMAsset, FungibleToken} {
            // Dealing with a bridged FungibleToken, continue
            switch view {
                case Type<FungibleTokenMetadataViews.FTDisplay>():
                    if let baseFTDisplay = self.views[Type<FungibleTokenMetadataViews.FTDisplay>()] as! FungibleTokenMetadataViews.FTDisplay? {
                        return FungibleTokenMetadataViews.FTDisplay(
                            name: crossVMToken.getName(),
                            symbol: crossVMToken.getSymbol(),
                            description: "This fungible token was bridged from EVM on Flow with the ERC20 contract address of "
                                .concat(crossVMToken.getEVMContractAddress().toString()),
                            externalURL: baseFTDisplay.externalURL,
                            logos: baseFTDisplay.logos,
                            socials: baseFTDisplay.socials
                        )
                    }
            }
        }
        return nil
    }

    /// Builds a thumbnail file based on the provided thumbnail file type identifier and optional IPFS file path
    ///
    /// @param thumbnailURI: The URI of the thumbnail file
    /// @param thumbnailFileTypeIdentifier: The type identifier of the thumbnail file
    /// @param ipfsFilePath: The optional IPFS file path if the thumbnail file is an IPFS file and has a path
    ///
    /// @returns The built thumbnail file
    ///
    access(all)
    view fun buildFile(uri: String, fileType: Type, ipfsFilePath: String?): {MetadataViews.File}? {
        switch fileType {
            case Type<MetadataViews.HTTPFile>():
                return MetadataViews.HTTPFile(url: uri)
            case Type<MetadataViews.IPFSFile>():
                return MetadataViews.IPFSFile(cid: uri, path: ipfsFilePath)
            default:
                return nil
        }
    }

    /// Builds a dictionary of ExternalURL views from a dictionary of URLs, helpful for creating a socials dictionary
    ///
    /// @param fromDict: The dictionary of URLs to convert
    ///
    /// @returns The dictionary of ExternalURL views
    ///
    access(all)
    view fun buildExternalURLMapping(fromDict: {String: String}): {String: MetadataViews.ExternalURL} {
        let res: {String: MetadataViews.ExternalURL} = {}
        for key in fromDict.keys {
            res[key] = MetadataViews.ExternalURL(fromDict[key]!)
        }
        return res
    }
    

    /*****************
        Constructs
     *****************/

    /// Admin resource allowing for view management
    ///
    access(all) resource Admin {
        /// Sets a view, indexing on the view type and replacing any existing view of the same type
        ///
        /// @param view: The view to set
        ///
        access(Metadata)
        fun setView(_ view: AnyStruct) {
            let old = FlowEVMBridgeResolver.views.remove(key: view.getType())
            FlowEVMBridgeResolver.views[view.getType()] = view

            emit ViewUpdated(viewType: view.getType().identifier, added: old == nil ? true : nil)
        }

        /// Removes the view with the given type
        ///
        /// @param type: The type of the view to remove
        ///
        access(Metadata)
        fun removeView(_ type: Type) {
            let old = FlowEVMBridgeResolver.views.remove(key: type)
            if old != nil {
                emit ViewUpdated(viewType: type.identifier, added: false)
            }
        }
    }

    init() {
        self.views = {}

        self.AdminStoragePath = /storage/flowEVMBridgeResolverAdmin

        // Initialize the Admin resource
        self.account.storage.save(<- create Admin(), to: FlowEVMBridgeResolver.AdminStoragePath)
    }
}
