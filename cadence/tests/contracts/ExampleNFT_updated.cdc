/* 
*
*  This is an example implementation of a Flow Non-Fungible Token
*  using the V2 standard.
*  It is not part of the official standard but it assumed to be
*  similar to how many NFTs would implement the core functionality.
*
*  This contract does not implement any sophisticated classification
*  system for its NFTs. It defines a simple NFT with minimal metadata.
*   
*/

import NonFungibleToken from 0x0000000000000001
import ViewResolver from 0x0000000000000001
import MetadataViews from 0x0000000000000001
import CrossVMMetadataViews from 0x0000000000000001

import EVM from 0x0000000000000001

import ICrossVM from 0x0000000000000007
import ICrossVMAsset from 0x0000000000000007
import SerializeMetadata from 0x0000000000000007
import FlowEVMBridgeCustomAssociationTypes from 0x0000000000000007
import FlowEVMBridgeUtils from 0x0000000000000007

/// THIS CONTRACT IS USED FOR TESTING PURPOSES ONLY
access(all) contract ExampleNFT: NonFungibleToken {

    /// Path where the minter should be stored
    /// The standard paths for the collection are stored in the collection resource type
    access(all) let MinterStoragePath: StoragePath

    /// We choose the name NFT here, but this type can have any name now
    /// because the interface does not require it to have a specific name any more
    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {

        access(all) let id: UInt64

        /// From the Display metadata view
        access(all) let name: String
        access(all) let description: String
        access(all) let thumbnail: String

        /// For the Royalties metadata view
        access(self) let royalties: [MetadataViews.Royalty]

        /// Generic dictionary of traits the NFT has
        access(self) let metadata: {String: AnyStruct}
    
        init(
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty],
            metadata: {String: AnyStruct},
        ) {
            self.id = self.uuid
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.royalties = royalties
            self.metadata = metadata
        }

        /// createEmptyCollection creates an empty Collection
        /// and returns it to the caller so that they can own NFTs
        /// @{NonFungibleToken.Collection}
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-ExampleNFT.createEmptyCollection(nftType: Type<@ExampleNFT.NFT>())
        }
    
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.EVMBridgedMetadata>(),
                Type<CrossVMMetadataViews.EVMBytesMetadata>(),
                Type<CrossVMMetadataViews.EVMPointer>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "Example NFT Edition", number: self.id, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://example-nft.onflow.org/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return ExampleNFT.resolveContractView(resourceType: Type<@ExampleNFT.NFT>(), viewType: Type<MetadataViews.NFTCollectionData>())
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return ExampleNFT.resolveContractView(resourceType: Type<@ExampleNFT.NFT>(), viewType: Type<MetadataViews.NFTCollectionDisplay>())
                case Type<MetadataViews.Traits>():
                    // exclude mintedTime and foo to show other uses of Traits
                    let excludedTraits = ["mintedTime", "foo"]
                    let traitsView = MetadataViews.dictToTraits(dict: self.metadata, excludedNames: excludedTraits)

                    // foo is a trait with its own rarity
                    let fooTraitRarity = MetadataViews.Rarity(score: 10.0, max: 100.0, description: "Common")
                    let fooTrait = MetadataViews.Trait(name: "foo", value: self.metadata["foo"], displayType: nil, rarity: fooTraitRarity)
                    traitsView.addTrait(fooTrait)
                    
                    return traitsView
                case Type<MetadataViews.EVMBridgedMetadata>():
                    let dataURI = SerializeMetadata.serializeNFTMetadataAsURI(&self as &{NonFungibleToken.NFT})
                    return MetadataViews.EVMBridgedMetadata(
                        name: "Example NFT",
                        symbol: "XMPL",
                        uri: MetadataViews.URI(baseURI: nil, value: dataURI)
                    )
                case Type<CrossVMMetadataViews.EVMBytesMetadata>():
                    // Resolving this view allows the VM bridge to pass abi-encoded metadata into the corresponding
                    // ERC721 implementation at the time of bridging. Below, this NFT's metadata is serialized then
                    // encoded, but implementations may choose a number of ways to bridge metadata including a proxy,
                    // custom serialization, or simply copy the minted Cadence NFTs onchain metadata as a JSON blob
                    // offchain (IPFS/HTTPS) at the time of minting if the metadata is static
                    let serialized = SerializeMetadata.serializeNFTMetadataAsURI(&self as &{NonFungibleToken.NFT})
                    let bytes = EVM.encodeABI([serialized])
                    return CrossVMMetadataViews.EVMBytesMetadata(
                        bytes: EVM.EVMBytes(value: bytes)
                    )
                case Type<CrossVMMetadataViews.EVMPointer>():
                    return CrossVMMetadataViews.EVMPointer(
                        cadenceType: self.getType(),
                        cadenceContractAddress: self.getType().address!,
                        evmContractAddress: ExampleNFT.getEVMContractAddress(),
                        nativeVM: CrossVMMetadataViews.VM.Cadence
                    )
            }
            return nil
        }
    }

    access(all) resource Collection: NonFungibleToken.Collection {
        /// dictionary of NFT conforming tokens
        /// NFT is a resource type with an `UInt64` ID field
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        access(all) var storagePath: StoragePath
        access(all) var publicPath: PublicPath

        init () {
            self.ownedNFTs <- {}
            let identifier = "cadenceExampleNFTCollection"
            self.storagePath = StoragePath(identifier: identifier)!
            self.publicPath = PublicPath(identifier: identifier)!
        }

        /// getSupportedNFTTypes returns a list of NFT types that this receiver accepts
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@ExampleNFT.NFT>()] = true
            return supportedTypes
        }

        /// Returns whether or not the given type is accepted by the collection
        /// A collection that can accept any type should just return true by default
        access(all) view fun isSupportedNFTType(type: Type): Bool {
           if type == Type<@ExampleNFT.NFT>() {
            return true
           } else {
            return false
           }
        }

        /// withdraw removes an NFT from the collection and moves it to the caller
        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Could not withdraw an NFT with the provided ID from the collection")

            return <-token
        }

        /// deposit takes a NFT and adds it to the collections dictionary
        /// and adds the ID to the id array
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @ExampleNFT.NFT

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

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)
        }

        /// Borrow the view resolver for the specified NFT ID
        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}? {
                return nft as &{ViewResolver.Resolver}
            }
            return nil
        }

        /// createEmptyCollection creates an empty Collection of the same type
        /// and returns it to the caller
        /// @return A an empty collection of the same type
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-ExampleNFT.createEmptyCollection(nftType: Type<@ExampleNFT.NFT>())
        }
    }

    /// createEmptyCollection creates an empty Collection for the specified NFT type
    /// and returns it to the caller so that they can own NFTs
    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    /// Function that returns all the Metadata Views implemented by a Non Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>(),
            Type<CrossVMMetadataViews.EVMPointer>()
        ]
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                let collectionData = MetadataViews.NFTCollectionData(
                    storagePath: /storage/cadenceExampleNFTCollection,
                    publicPath: /public/cadenceExampleNFTCollection,
                    publicCollection: Type<&ExampleNFT.Collection>(),
                    publicLinkedType: Type<&ExampleNFT.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-ExampleNFT.createEmptyCollection(nftType: Type<@ExampleNFT.NFT>())
                    })
                )
                return collectionData
            case Type<MetadataViews.NFTCollectionDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                    ),
                    mediaType: "image/svg+xml"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "The Example Collection",
                    description: "This collection is used as an example to help you develop your next Flow NFT.",
                    externalURL: MetadataViews.ExternalURL("https://example-nft.onflow.org"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                    }
                )
            case Type<CrossVMMetadataViews.EVMPointer>():
                return CrossVMMetadataViews.EVMPointer(
                    cadenceType: Type<@ExampleNFT.NFT>(),
                    cadenceContractAddress: self.account.address,
                    evmContractAddress: self.getEVMContractAddress(),
                    nativeVM: CrossVMMetadataViews.VM.Cadence
                )
        }
        return nil
    }

    /// Resource that an admin or something similar would own to be
    /// able to mint new NFTs
    ///
    access(all) resource NFTMinter {

        /// mintNFT mints a new NFT with a new ID
        /// and returns it to the calling context
        access(all) fun mintNFT(
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty]
        ): @ExampleNFT.NFT {

            let metadata: {String: AnyStruct} = {}
            let currentBlock = getCurrentBlock()
            metadata["mintedBlock"] = currentBlock.height
            metadata["mintedTime"] = currentBlock.timestamp

            // this piece of metadata will be used to show embedding rarity into a trait
            metadata["foo"] = "bar"

            // create a new NFT
            var newNFT <- create NFT(
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: royalties,
                metadata: metadata,
            )

            return <-newNFT
        }
    }

    /// This method accesses the ERC721 address from storage due to nuances in the Cadence testing framework. Typically,
    /// the contract would be updated with a hardcoded value once the ERC721 contract address is known, but this cannot
    /// be determined prior to deployment in the testing environment. Instead, the EVM address is configured in account
    /// storage once the test ERC721 contract has been deployed.
    access(self)
    view fun getEVMContractAddress(): EVM.EVMAddress {
        return self.account.storage.copy<EVM.EVMAddress>(from: /storage/erc721ContractAddress)
            ?? panic("Corresponding ERC721 contract address has not been configured at /storage/erc721ContractAddress")
    }

    init() {

        // Set the named paths
        self.MinterStoragePath = /storage/cadenceExampleNFTMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        let defaultStoragePath = collection.storagePath
        let defaultPublicPath = collection.publicPath
        self.account.storage.save(<-collection, to: defaultStoragePath)

        // create a public capability for the collection
        let collectionCap = self.account.capabilities.storage.issue<&ExampleNFT.Collection>(defaultStoragePath)
        self.account.capabilities.publish(collectionCap, at: defaultPublicPath)

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
}
 