import NonFungibleToken from 0xf8d6e0586b0a20c7
import MetadataViews from 0xf8d6e0586b0a20c7
import ViewResolver from 0xf8d6e0586b0a20c7
import FlowToken from 0x0ae53cb6e3f42a79

import EVM from 0xf8d6e0586b0a20c7

import IFlowEVMNFTBridge from 0xf8d6e0586b0a20c7
import FlowEVMBridgeConfig from 0xf8d6e0586b0a20c7
import FlowEVMBridgeUtils from 0xf8d6e0586b0a20c7
import FlowEVMBridge from 0xf8d6e0586b0a20c7
import ICrossVM from 0xf8d6e0586b0a20c7
import CrossVMNFT from 0xf8d6e0586b0a20c7

// TODO:
// - [ ] Consider the metadata views that we'll resolve for EVM-native NFTs
access(all) contract CONTRACT_NAME: ICrossVM, IFlowEVMNFTBridge, ViewResolver {

    /// Pointer to the Factory deployed Solidity contract address defining the bridged asset
    access(all) let evmNFTContractAddress: EVM.EVMAddress
    /// Name of the NFT collection defined in the corresponding ERC721 contract
    access(all) let name: String
    /// Symbol of the NFT collection defined in the corresponding ERC721 contract
    access(all) let symbol: String
    
    /// Path where the minter should be stored
    /// The standard paths for the collection are stored in the collection resource type
    access(all) let MinterStoragePath: StoragePath

    /// We choose the name NFT here, but this type can have any name now
    /// because the interface does not require it to have a specific name any more
    access(all) resource NFT: CrossVMNFT.EVMNFT, NonFungibleToken.NFT, ViewResolver.Resolver {

        access(all) let id: UInt64
        access(all) let evmID: UInt256
        access(all) let name: String
        access(all) let symbol: String

        access(all) let uri: String
        access(all) let metadata: {String: AnyStruct}

        init(
            name: String,
            symbol: String,
            id: UInt64,
            evmID: UInt256,
            uri: String,
            metadata: {String: AnyStruct}
        ) {
            self.name = name
            self.symbol = symbol
            self.id = id
            self.evmID = evmID
            self.uri = uri
            self.metadata = metadata
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<CrossVMNFT.BridgedMetadata>():
                    return CrossVMNFT.BridgedMetadata(
                        name: self.name,
                        symbol: self.symbol,
                        uri: CrossVMNFT.URI(self.uri)
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.NFTCollectionData>():
                    return CONTRACT_NAME.getCollectionData(nftType: Type<@CONTRACT_NAME.NFT>())
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return CONTRACT_NAME.getCollectionDisplay(nftType: Type<@CONTRACT_NAME.NFT>())
            }
            return nil
        }

        /// public function that anyone can call to create a new empty collection
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- create CONTRACT_NAME.Collection()
        }

        /* --- CrossVMNFT conformance --- */

        access(all) fun getEVMContractAddress(): EVM.EVMAddress {
            return CONTRACT_NAME.getEVMContractAddress()
        }

        access(all) fun tokenURI(): String {
            return self.uri
        }
    }

    access(all) resource Collection: NonFungibleToken.Collection, CrossVMNFT.EVMBridgeableCollection {
        /// dictionary of NFT conforming tokens
        /// NFT is a resource type with an `UInt64` ID field
        access(contract) var ownedNFTs: @{UInt64: CONTRACT_NAME.NFT}

        access(self) var storagePath: StoragePath
        access(self) var publicPath: PublicPath

        /// Return the default storage path for the collection
        access(all) view fun getDefaultStoragePath(): StoragePath? {
            return self.storagePath
        }

        /// Return the default public path for the collection
        access(all) view fun getDefaultPublicPath(): PublicPath? {
            return self.publicPath
        }

        init () {
            self.ownedNFTs <- {}
            let identifier = "CONTRACT_NAMECollection"
            self.storagePath = StoragePath(identifier: identifier)!
            self.publicPath = PublicPath(identifier: identifier)!
        }

        /// getSupportedNFTTypes returns a list of NFT types that this receiver accepts
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@CONTRACT_NAME.NFT>()] = true
            return supportedTypes
        }

        /// Returns whether or not the given type is accepted by the collection
        /// A collection that can accept any type should just return true by default
        access(all) view fun isSupportedNFTType(type: Type): Bool {
           if type == Type<@CONTRACT_NAME.NFT>() {
            return true
           } else {
            return false
           }
        }

        access(ICrossVMNFT.Bridgeable) fun bridgeToEVM(id: UInt64, to: EVM.EVMAddress, tollFee: @{FungibleToken.Vault}) {
            let token <- self.withdraw(withdrawID: id)
            CONTRACT_NAME.bridgeNFTToEVM(nft: <-token, to: to, tollFee: <-tollFee)
        }

        /// withdraw removes an NFT from the collection and moves it to the caller
        access(NonFungibleToken.Withdrawable) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Could not withdraw an NFT with the provided ID from the collection")

            return <-token
        }

        /// deposit takes a NFT and adds it to the collections dictionary
        /// and adds the ID to the id array
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @CONTRACT_NAME.NFT

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[token.id] <- token

            destroy oldToken
        }

        /// getIDs returns an array of the IDs that are in the collection
        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        /// Gets the amount of NFTs stored in the collection
        access(all) view fun getLength(): Int {
            return self.ownedNFTs.keys.length
        }

        access(all) fun borrowEVMNFT(id: UInt64): &{NonFungibleToken.NFT, ICrossVMNFT.EVMNFT}? {
            return &self.ownedNFTs[id] as &{NonFungibleToken.NFT, ICrossVMNFT.EVMNFT}?
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        /// Borrow the view resolver for the specified NFT ID
        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &CONTRACT_NAME.NFT? {
                return nft as &{ViewResolver.Resolver}
            }
            return nil
        }
    }

    /// public function that anyone can call to create a new empty collection
    /// Since multiple collection types can be defined in a contract,
    /// The caller needs to specify which one they want to create
    access(all) fun createEmptyCollection(): @CONTRACT_NAME.Collection {
        return <- create Collection()
    }

    /// Function that returns all the Metadata Views implemented by a Non Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all) view fun getViews(): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all) fun resolveView(_ view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.NFTCollectionData>():
                return CONTRACT_NAME.getCollectionData(nftType: Type<@CONTRACT_NAME.NFT>())
            case Type<MetadataViews.NFTCollectionDisplay>():
                return CONTRACT_NAME.getCollectionDisplay(nftType: Type<@CONTRACT_NAME.NFT>())
        }
        return nil
    }

    /// resolve a type to its CollectionData so you know where to store it
    /// Returns `nil` if no collection type exists for the specified NFT type
    access(all) view fun getCollectionData(nftType: Type): MetadataViews.NFTCollectionData? {
        switch nftType {
            case Type<@CONTRACT_NAME.NFT>():
                let collectionRef = self.account.storage.borrow<&CONTRACT_NAME.Collection>(
                        from: /storage/CONTRACT_NAMECollection
                    ) ?? panic("Could not borrow a reference to the stored collection")
                let collectionData = MetadataViews.NFTCollectionData(
                    storagePath: collectionRef.getDefaultStoragePath()!,
                    publicPath: collectionRef.getDefaultPublicPath()!,
                    providerPath: /private/CONTRACT_NAMECollection,
                    publicCollection: Type<&CONTRACT_NAME.Collection>(),
                    publicLinkedType: Type<&CONTRACT_NAME.Collection>(),
                    providerLinkedType: Type<auth(NonFungibleToken.Withdrawable) &CONTRACT_NAME.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-CONTRACT_NAME.createEmptyCollection()
                    })
                )
                return collectionData
            default:
                return nil
        }
    }

    /// Returns the CollectionDisplay view for the NFT type that is specified
    // TODO: Replace with generalized bridge collection display
    access(all) view fun getCollectionDisplay(nftType: Type): MetadataViews.NFTCollectionDisplay? {
        switch nftType {
            case Type<@CONTRACT_NAME.NFT>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                    ),
                    mediaType: "image/svg+xml"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "The FlowVM Bridged NFT Collection",
                    description: "This collection was bridged from Flow EVM.",
                    externalURL: MetadataViews.ExternalURL("https://example-nft.onflow.org"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {}
                )
            default:
                return nil
        }
    }

    /* --- ICrossVM conformance --- */
    //
    ///
    access(all) fun getEVMContractAddress(): EVM.EVMAddress {
        return self.evmNFTContractAddress
    }

    /* --- IFlowEVMNFTBridge conformance --- */
    //
    ///
    access(all) fun bridgeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault) {
        pre {
            token.getType() == Type<@CONTRACT_NAME.NFT>(): "Unsupported NFT type"
            tollFee.balance >= FlowEVMBridgeConfig.fee: "Insufficient fee provided"
        }
        let tokenID: UInt64 = token.getID()
        assert(
            FlowEVMBridgeUtils.isOwnerOrApproved(
                ofNFT: UInt256(tokenID),
                owner: FlowEVMBridgeUtils.borrowCOA().address(),
                evmContractAddress: self.getEVMContractAddress()
            ), message: "The requested NFT is not owned by the bridge COA account"
        )
        let cast <- token as! @CONTRACT_NAME.NFT
        self.burnNFT(nft: <-cast)

        FlowEVMBridge.emitBridgeNFTFromEVMEvent(
            type: Type<@CONTRACT_NAME.NFT>(),
            id: tokenID,
            evmID: UInt256,
            caller: EVM.EVMAddress,
            evmContractAddress: EVM.EVMAddress,
            flowNative: Bool
        )
        
        FlowEVMBridgeUtils.call(
            signature: "safeTransferFrom(address,address,uint256)",
            targetEVMAddress: self.evmNFTContractAddress,
            args: [self.getEVMContractAddress(), to, tokenID],
            gasLimit: 15000000,
            value: 0.0
        )
    }

    access(all) fun bridgeNFTFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @FlowToken.Vault
    ): @{NonFungibleToken.NFT} {
        // TODO: Implement
        return <-create NFT(
            name: "",
            symbol: "",
            id: 0,
            evmID: 0,
            uri: "",
            metadata: {}
        )
    }

    // TODO: Replace with standard burning mechanism & event
    access(self) fun burnNFT(nft: @CONTRACT_NAME.NFT) {
        destroy nft
    }

    /// Resource that an admin or something similar would own to be
    /// able to mint new NFTs
    ///
    access(all) resource NFTMinter {

        /// mintNFT mints a new NFT with a new ID
        /// and returns it to the calling context
        access(all) fun mintNFT(
            name: String,
            symbol: String,
            id: UInt64,
            evmID: UInt256,
            uri: String
        ): @CONTRACT_NAME.NFT {

            let metadata: {String: AnyStruct} = {}
            let currentBlock = getCurrentBlock()
            metadata["Bridged Block"] = currentBlock.height
            metadata["Bridged Time"] = currentBlock.timestamp

            // create a new NFT
            var newNFT <- create NFT(
                name: name,
                symbol: symbol,
                id: id,
                evmID: evmID,
                uri: uri,
                metadata: metadata
            )

            return <-newNFT
        }
    }

    init(name: String, symbol: String, evmContractAddress: EVM.EVMAddress) {
        self.evmNFTContractAddress = evmContractAddress
        self.name = name
        self.symbol = symbol

        // Set the named paths
        self.MinterStoragePath = /storage/CONTRACT_NAMEMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        let defaultStoragePath = collection.getDefaultStoragePath()!
        let defaultPublicPath = collection.getDefaultPublicPath()!
        self.account.storage.save(<-collection, to: defaultStoragePath)

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
}
