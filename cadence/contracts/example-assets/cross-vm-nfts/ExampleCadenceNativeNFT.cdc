/* 
 *
 * This is an example implementation of a Cadence-native cross-VM NFT. Cadence-native here meaning 
 * that the NFT is distributed in Cadence and cross-VM meaning that the project is deployed across
 * Cadence & EVM (as an ERC721). Movement between VMs is facilitated by the canonical VM bridge.
 * 
 * For more information on cross-VM NFT implementations, see FLIP-318: (https://github.com/onflow/flips/issues/318)
 *   
 */

import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "CrossVMMetadataViews"

import "EVM"

import "ICrossVM"
import "ICrossVMAsset"
import "SerializeMetadata"
import "FlowEVMBridgeCustomAssociationTypes"
import "FlowEVMBridgeUtils"

access(all) contract ExampleCadenceNativeNFT: NonFungibleToken, ICrossVM, ICrossVMAsset {

    access(self) let evmContractAddress: EVM.EVMAddress
    access(self) let name: String
    access(self) let symbol: String
    
    /// The standard paths for the collection are stored in the collection resource type
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    /// The storage path where the Minter is stored
    access(all) let MinterStoragePath: StoragePath

    access(all) event MintedNFT(id: UInt64, to: Address?)

    /* ICrossVMAsset conformance */

    /// Returns the name of the asset
    access(all) view fun getName(): String {
        return self.name
    }
    /// Returns the symbol of the asset
    access(all) view fun getSymbol(): String {
        return self.symbol
    }
    
    /* ICrossVM conformance */

    /// Returns the associated EVM contract address
    access(all) view fun getEVMContractAddress(): EVM.EVMAddress {
        return self.evmContractAddress
    }

    /// We choose the name NFT here, but this type can have any name now
    /// because the interface does not require it to have a specific name any more
    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {

        access(all) let id: UInt64

        /// From the Display metadata view
        access(all) let name: String
        access(all) let description: String

        /// Generic dictionary of traits the NFT has
        access(self) let metadata: {String: AnyStruct}
    
        init(
            name: String,
            description: String,
            metadata: {String: AnyStruct},
        ) {
            self.id = self.uuid
            self.name = name
            self.description = description
            self.metadata = metadata
        }

        /// createEmptyCollection creates an empty Collection
        /// and returns it to the caller so that they can own NFTs
        /// @{NonFungibleToken.Collection}
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-ExampleCadenceNativeNFT.createEmptyCollection(nftType: Type<@ExampleCadenceNativeNFT.NFT>())
        }
    
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
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
                    let collectionDisplay = (ExampleCadenceNativeNFT.resolveContractView(resourceType: self.getType(), viewType: Type<MetadataViews.NFTCollectionDisplay>()) as! MetadataViews.NFTCollectionDisplay?)!
                    return MetadataViews.Display(
                        name: ExampleCadenceNativeNFT.getName().concat(" #").concat(self.id.toString()),
                        description: collectionDisplay.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: "https://example-nft.flow.com/nft/".concat(self.id.toString())
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://example-nft.flow.com/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return ExampleCadenceNativeNFT.resolveContractView(resourceType: Type<@ExampleCadenceNativeNFT.NFT>(), viewType: Type<MetadataViews.NFTCollectionData>())
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return ExampleCadenceNativeNFT.resolveContractView(resourceType: Type<@ExampleCadenceNativeNFT.NFT>(), viewType: Type<MetadataViews.NFTCollectionDisplay>())
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
                        name: ExampleCadenceNativeNFT.name,
                        symbol: ExampleCadenceNativeNFT.symbol,
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
                        evmContractAddress: ExampleCadenceNativeNFT.getEVMContractAddress(),
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

        init () {
            self.ownedNFTs <- {}
        }

        /// getSupportedNFTTypes returns a list of NFT types that this receiver accepts
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@ExampleCadenceNativeNFT.NFT>()] = true
            return supportedTypes
        }

        /// Returns whether or not the given type is accepted by the collection
        /// A collection that can accept any type should just return true by default
        access(all) view fun isSupportedNFTType(type: Type): Bool {
           if type == Type<@ExampleCadenceNativeNFT.NFT>() {
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
            let token <- token as! @ExampleCadenceNativeNFT.NFT

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
            return <-ExampleCadenceNativeNFT.createEmptyCollection(nftType: Type<@ExampleCadenceNativeNFT.NFT>())
        }
    }

    /// createEmptyCollection creates an empty Collection for the specified NFT type
    /// and returns it to the caller so that they can own NFTs
    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    /// Function that returns all the Metadata Views implemented by a Non Fungible Token
    ///
    /// @param resourceType: The Type of the relevant NFT defined in this contract.
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>(),
            Type<MetadataViews.EVMBridgedMetadata>(),
            Type<CrossVMMetadataViews.EVMPointer>()
        ]
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param resourceType: The Type of the relevant NFT defined in this contract.
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                let collectionData = MetadataViews.NFTCollectionData(
                    storagePath: ExampleCadenceNativeNFT.CollectionStoragePath,
                    publicPath: ExampleCadenceNativeNFT.CollectionPublicPath,
                    publicCollection: Type<&ExampleCadenceNativeNFT.Collection>(),
                    publicLinkedType: Type<&ExampleCadenceNativeNFT.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-ExampleCadenceNativeNFT.createEmptyCollection(nftType: Type<@ExampleCadenceNativeNFT.NFT>())
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
                    name: "The Example EVM-Native NFT Collection",
                    description: "This collection is used as an example to help you develop your next EVM-native cross-VM Flow NFT.",
                    externalURL: MetadataViews.ExternalURL("https://example-nft.flow.com"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                    }
                )
            case Type<MetadataViews.EVMBridgedMetadata>():
                let collectionDisplay = (self.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionDisplay>())
                    as! MetadataViews.NFTCollectionDisplay?)!
                let dataURI = SerializeMetadata.serializeFromDisplays(nftDisplay: nil, collectionDisplay: collectionDisplay)
                    ?? panic("Could not serialize contract-level metadata for ExampleCadenceNativeNFT")
                return MetadataViews.EVMBridgedMetadata(
                    name: self.name,
                    symbol: self.symbol,
                    uri: MetadataViews.URI(baseURI: nil, value: dataURI)
                )
            case Type<CrossVMMetadataViews.EVMPointer>():
                return CrossVMMetadataViews.EVMPointer(
                    cadenceType: Type<@ExampleCadenceNativeNFT.NFT>(),
                    cadenceContractAddress: self.account.address,
                    evmContractAddress: self.getEVMContractAddress(),
                    nativeVM: CrossVMMetadataViews.VM.Cadence
                )
        }
        return nil
    }

    /* Minter */
    //
    /// Resource that an admin or something similar would own to be
    /// able to mint new NFTs
    ///
    access(all) resource NFTMinter {

        /// mintNFT mints a new NFT with a new ID
        /// and returns it to the calling context
        access(all) fun mintNFT(
            name: String,
            description: String,
            to: &{NonFungibleToken.Collection}
        ) {

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
                metadata: metadata,
            )

            emit MintedNFT(id: newNFT.id, to: to.owner?.address)
            to.deposit(token: <-newNFT)
        }
    }

    /// Contract initialization
    ///
    /// @param erc721Bytecode: The bytecode for the ERC721 contract which is deployed via this contract account's
    ///     CadenceOwnedAccount. Any account can deploy the corresponding ERC721 contract, but it's done here for
    ///     demonstration and ease of EVM contract assignment.
    ///
    init(erc721Bytecode: String, name: String, symbol: String) {

        // Set the named paths
        self.CollectionStoragePath = /storage/ExampleCadenceNativeNFTCollection
        self.CollectionPublicPath = /public/ExampleCadenceNativeNFTFulfillmentMinter
        self.MinterStoragePath = /storage/ExampleCadenceNativeNFTMinter

        self.name = name
        self.symbol = symbol

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)

        // Create a public capability for the collection
        let collectionCap = self.account.capabilities.storage.issue<&ExampleCadenceNativeNFT.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(collectionCap, at: self.CollectionPublicPath)

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)

        // Configure a COA so this contract can call into EVM
        if self.account.storage.type(at: /storage/evm) != Type<@EVM.CadenceOwnedAccount>() {
            self.account.storage.save(<-EVM.createCadenceOwnedAccount(), to: /storage/evm)
            let coaCap = self.account.capabilities.storage.issue<&EVM.CadenceOwnedAccount>(/storage/evm)
            self.account.capabilities.publish(coaCap, at: /public/evm)
        }
        let coa = self.account.storage.borrow<auth(EVM.Owner) &EVM.CadenceOwnedAccount>(
                from: /storage/evm
            )!

        // Append the constructor args to the provided contract bytecode
        // NOTE: Be sure to confirm the order of your contract's constructor args and encode accordingly
        let cadenceAddressStr = self.account.address.toString()
        let cadenceIdentifier = Type<@ExampleCadenceNativeNFT.NFT>().identifier
        let vmBridgeAddress = FlowEVMBridgeUtils.getBridgeCOAEVMAddress()
        let encodedConstructorArgs = EVM.encodeABI([name, symbol, cadenceAddressStr, cadenceIdentifier, vmBridgeAddress])
        let finalBytecode = erc721Bytecode.decodeHex().concat(encodedConstructorArgs)

        // Deploy the provided EVM contract, passing the defined value of FLOW on init
        let deployResult = coa.deploy(
            code: finalBytecode,
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(
            deployResult.status == EVM.Status.successful,
            message: "ERC721 deployment failed with message: ".concat(deployResult.errorMessage)
        )

        self.evmContractAddress = deployResult.deployedContract!
    }
}
 