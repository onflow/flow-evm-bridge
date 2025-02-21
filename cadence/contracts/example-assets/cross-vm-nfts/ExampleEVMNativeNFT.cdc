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

import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "CrossVMMetadataViews"

import "EVM"

import "ICrossVM"
import "ICrossVMAsset"
import "FlowEVMBridgeCustomAssociations"

access(all) contract ExampleEVMNativeNFT: NonFungibleToken, ICrossVM, ICrossVMAsset {

    access(self) let evmContractAddress: EVM.EVMAddress
    access(self) let name: String
    access(self) let symbol: String
    
    /// Path where the fulfillment minter should be stored
    /// The standard paths for the collection are stored in the collection resource type
    access(all) let FulfillmentMinterStoragePath: StoragePath

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

    /* Custom Getters */

    /// Returns the token URI for the provided ERC721 id, treating the corresponding ERC721 as the source of truth
    access(all) fun tokenURI(id: UInt256): String {
        let tokenURIRes = self.call(
                signature: "tokenURI(uint256)",
                targetEVMAddress: self.getEVMContractAddress(),
                args: [id],
                gasLimit: 100_000,
                value: 0.0
            )
        assert(
            tokenURIRes.status == EVM.Status.successful,
            message: "Error calling ERC721.tokenURI(uint256) with message: ".concat(tokenURIRes.errorMessage)
        )
        let decodedURIData = EVM.decodeABI(types: [Type<String>()], data: tokenURIRes.data)
        assert(
            decodedURIData.length == 1,
            message: "Unexpected tokenURI(uint256) return length of ".concat(decodedURIData.length.toString())
        )
        return decodedURIData[0] as! String
    }

    /// Returns the token URI for the provided ERC721 id, treating the corresponding ERC721 as the source of truth
    access(all) fun contractURI(): String {
        let contractURIRes = self.call(
                signature: "contractURI()",
                targetEVMAddress: self.getEVMContractAddress(),
                args: [],
                gasLimit: 100_000,
                value: 0.0
            )
        assert(
            contractURIRes.status == EVM.Status.successful,
            message: "Error calling ERC721.contractURI(uint256) with message: ".concat(contractURIRes.errorMessage)
        )
        let decodedURIData = EVM.decodeABI(types: [Type<String>()], data: contractURIRes.data)
        assert(
            decodedURIData.length == 1,
            message: "Unexpected contractURI(uint256) return length of ".concat(decodedURIData.length.toString())
        )
        return decodedURIData[0] as! String
    }

    /* --- Internal Helpers --- */

    access(self) fun call(
        signature: String,
        targetEVMAddress: EVM.EVMAddress,
        args: [AnyStruct],
        gasLimit: UInt64,
        value: UFix64
    ): EVM.Result {
        let calldata = EVM.encodeABIWithSignature(signature, args)
        let valueBalance = EVM.Balance(attoflow: 0)
        valueBalance.setFLOW(flow: value)
        return self.borrowCOA().call(
            to: targetEVMAddress,
            data: calldata,
            gasLimit: gasLimit,
            value: valueBalance
        )
    }

    access(self) view fun borrowCOA(): auth(EVM.Owner) &EVM.CadenceOwnedAccount {
        return self.account.storage.borrow<auth(EVM.Owner) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow CadenceOwnedAccount (COA) from /storage/evm. "
            .concat("Ensure this account has a COA configured to successfully call into EVM."))
    }

    /// We choose the name NFT here, but this type can have any name now
    /// because the interface does not require it to have a specific name any more
    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {

        access(all) let id: UInt64
    
        init(
            erc721ID: UInt256
        ) {
            pre {
                erc721ID <= UInt256(UInt64.max):
                "Provided EVM ID ".concat(erc721ID.toString())
                .concat(" exceeds the assignable Cadence ID of UInt64.max ").concat(UInt64.max.toString())
            }
            self.id = UInt64(erc721ID)
        }

        /// createEmptyCollection creates an empty Collection
        /// and returns it to the caller so that they can own NFTs
        /// @{NonFungibleToken.Collection}
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-ExampleEVMNativeNFT.createEmptyCollection(nftType: Type<@ExampleEVMNativeNFT.NFT>())
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
                Type<CrossVMMetadataViews.EVMPointer>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    let collectionDisplay = (ExampleEVMNativeNFT.resolveContractView(resourceType: self.getType(), viewType: Type<MetadataViews.NFTCollectionDisplay>()) as! MetadataViews.NFTCollectionDisplay?)!
                    return MetadataViews.Display(
                        name: ExampleEVMNativeNFT.getName().concat(" #").concat(self.id.toString()),
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
                    return ExampleEVMNativeNFT.resolveContractView(resourceType: Type<@ExampleEVMNativeNFT.NFT>(), viewType: Type<MetadataViews.NFTCollectionData>())
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return ExampleEVMNativeNFT.resolveContractView(resourceType: Type<@ExampleEVMNativeNFT.NFT>(), viewType: Type<MetadataViews.NFTCollectionDisplay>())
                case Type<MetadataViews.EVMBridgedMetadata>():
                    // retrieve the token URI from the ERC721 as source of truth
                    let uri = ExampleEVMNativeNFT.tokenURI(id: UInt256(self.id))

                    return MetadataViews.EVMBridgedMetadata(
                        name: ExampleEVMNativeNFT.getName(),
                        symbol: ExampleEVMNativeNFT.getSymbol(),
                        uri: MetadataViews.URI(baseURI: nil, value: uri)
                    )
                case Type<CrossVMMetadataViews.EVMPointer>():
                    return CrossVMMetadataViews.EVMPointer(
                        cadenceType: self.getType(),
                        cadenceContractAddress: self.getType().address!,
                        evmContractAddress: ExampleEVMNativeNFT.getEVMContractAddress(),
                        nativeVM: CrossVMMetadataViews.VM.EVM
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
            let identifier = "cadenceExampleEVMNativeNFTCollection"
            self.storagePath = StoragePath(identifier: identifier)!
            self.publicPath = PublicPath(identifier: identifier)!
        }

        /// getSupportedNFTTypes returns a list of NFT types that this receiver accepts
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@ExampleEVMNativeNFT.NFT>()] = true
            return supportedTypes
        }

        /// Returns whether or not the given type is accepted by the collection
        /// A collection that can accept any type should just return true by default
        access(all) view fun isSupportedNFTType(type: Type): Bool {
           if type == Type<@ExampleEVMNativeNFT.NFT>() {
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
            let token <- token as! @ExampleEVMNativeNFT.NFT

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
            return <-ExampleEVMNativeNFT.createEmptyCollection(nftType: Type<@ExampleEVMNativeNFT.NFT>())
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
                    storagePath: /storage/cadenceExampleEVMNativeNFTCollection,
                    publicPath: /public/cadenceExampleEVMNativeNFTCollection,
                    publicCollection: Type<&ExampleEVMNativeNFT.Collection>(),
                    publicLinkedType: Type<&ExampleEVMNativeNFT.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-ExampleEVMNativeNFT.createEmptyCollection(nftType: Type<@ExampleEVMNativeNFT.NFT>())
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
                // retrieve the contract URI from the ERC721 as source of truth
                let uri = ExampleEVMNativeNFT.contractURI()
                return MetadataViews.EVMBridgedMetadata(
                        name: ExampleEVMNativeNFT.getName(),
                        symbol: ExampleEVMNativeNFT.getSymbol(),
                        uri: MetadataViews.URI(baseURI: nil, value: uri)
                    )
            case Type<CrossVMMetadataViews.EVMPointer>():
                return CrossVMMetadataViews.EVMPointer(
                    cadenceType: Type<@ExampleEVMNativeNFT.NFT>(),
                    cadenceContractAddress: self.account.address,
                    evmContractAddress: self.getEVMContractAddress(),
                    nativeVM: CrossVMMetadataViews.VM.EVM
                )
        }
        return nil
    }

    /* FlowEVMBridgeCustomAssociations.NFTFulfillmentMinter Conformance */

    /// Resource that allows the bridge to mint Cadence NFTs as needed when fulfilling movement of
    /// EVM-native ERC721 tokens from Flow EVM.
    ///
    access(all) resource NFTMinter : FlowEVMBridgeCustomAssociations.NFTFulfillmentMinter {

        /// Getter for the type of NFT that's fulfilled by this implementation
        ///
        access(all) view fun getFulfilledType(): Type {
            return Type<@ExampleEVMNativeNFT.NFT>()
        }

        /// Called by the VM bridge when moving NFTs from EVM into Cadence if the NFT is not in escrow. Since such NFTs
        /// are EVM-native, they are distributed in EVM. On the Cadence side, those NFTs are handled by a mint & escrow
        /// pattern. On moving to EVM, the NFTs are minted if not in escrow at the time of bridging.
        ///
        /// @param id: The id of the token being fulfilled from EVM
        ///
        /// @return The NFT fulfilled from EVM as its Cadence implementation
        ///
        access(FlowEVMBridgeCustomAssociations.FulfillFromEVM)
        fun fulfillFromEVM(id: UInt256): @{NonFungibleToken.NFT} {
            return <- create NFT(erc721ID: id)
        }
    }

    /// Contract initialization
    ///
    /// @param erc721Bytecode: The bytecode for the ERC721 contract which is deployed via this contract account's
    ///     CadenceOwnedAccount. Any account can deploy the corresponding ERC721 contract, but it's done here for
    ///     demonstration and ease of EVM contract assignment.
    ///
    init(erc721Bytecode: String) {

        // Set the named paths
        self.FulfillmentMinterStoragePath = /storage/cadenceExampleEVMNativeNFTFulfillmentMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        let defaultStoragePath = collection.storagePath
        let defaultPublicPath = collection.publicPath
        self.account.storage.save(<-collection, to: defaultStoragePath)

        // Create a public capability for the collection
        let collectionCap = self.account.capabilities.storage.issue<&ExampleEVMNativeNFT.Collection>(defaultStoragePath)
        self.account.capabilities.publish(collectionCap, at: defaultPublicPath)

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.FulfillmentMinterStoragePath)

        // Configure a COA so this contract can call into EVM
        if self.account.storage.type(at: /storage/evm) != Type<@EVM.CadenceOwnedAccount>() {
            self.account.storage.save(<-EVM.createCadenceOwnedAccount(), to: /storage/evm)
            let coaCap = self.account.capabilities.storage.issue<&EVM.CadenceOwnedAccount>(/storage/evm)
            self.account.capabilities.publish(coaCap, at: /public/evm)
        }
        let coa = self.account.storage.borrow<auth(EVM.Owner) &EVM.CadenceOwnedAccount>(
                from: /storage/evm
            )!

        // Deploy the provided EVM contract, passing the defined value of FLOW on init
        let deployResult = coa.deploy(
            code: erc721Bytecode.decodeHex(),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(
            deployResult.status == EVM.Status.successful,
            message: "ERC721 deployment failed with message: ".concat(deployResult.errorMessage)
        )

        self.evmContractAddress = deployResult.deployedContract!

        // Assign name & symbol based on ERC721 contract
        let nameRes = coa.call(
            to: self.evmContractAddress,
            data: EVM.encodeABIWithSignature("name()", []),
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: 0)
        )
        let symbolRes = coa.call(
            to: self.evmContractAddress,
            data: EVM.encodeABIWithSignature("symbol()", []),
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(
            nameRes.status == EVM.Status.successful,
            message: "Error on ERC721.name() call with message: ".concat(nameRes.errorMessage)
        )
        assert(
            symbolRes.status == EVM.Status.successful,
            message: "Error on ERC721.symbol() call with message: ".concat(symbolRes.errorMessage)
        )

        let decodedNameData = EVM.decodeABI(types: [Type<String>()], data: nameRes.data)
        let decodedSymbolData = EVM.decodeABI(types: [Type<String>()], data: symbolRes.data)
        assert(decodedNameData.length == 1, message: "Unexpected name() return length of ".concat(decodedNameData.length.toString()))
        assert(decodedSymbolData.length == 1, message: "Unexpected symbol() return length of ".concat(decodedSymbolData.length.toString()))

        self.name = decodedNameData[0] as! String
        self.symbol = decodedSymbolData[0] as! String
    }
}
 