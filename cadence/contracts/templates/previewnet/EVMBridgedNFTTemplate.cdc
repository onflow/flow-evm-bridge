import NonFungibleToken from 0xb6763b4399a888c8
import MetadataViews from 0xb6763b4399a888c8
import ViewResolver from 0xb6763b4399a888c8
import FungibleToken from 0xa0225e7000ac82a9
import FlowToken from 0x4445e7ad11568276

import EVM from 0xb6763b4399a888c8

import ICrossVM from 0x7792cfb75d8dfdd8
import IEVMBridgeNFTMinter from 0x7792cfb75d8dfdd8
import FlowEVMBridgeNFTEscrow from 0x7792cfb75d8dfdd8
import FlowEVMBridgeConfig from 0x7792cfb75d8dfdd8
import FlowEVMBridgeUtils from 0x7792cfb75d8dfdd8
import FlowEVMBridge from 0x7792cfb75d8dfdd8
import CrossVMNFT from 0x7792cfb75d8dfdd8

/// This contract is a template used by FlowEVMBridge to define EVM-native NFTs bridged from Flow EVM to Flow.
/// Upon deployment of this contract, the contract name is derived as a function of the asset type (here an ERC721 aka
/// an NFT) and the contract's EVM address. The derived contract name is then joined with this contract's code,
/// prepared as chunks in FlowEVMBridgeTemplates before being deployed to the Flow EVM Bridge account.
///
/// On bridging, the ERC721 is transferred to the bridge's CadenceOwnedAccount EVM address and a new NFT is minted from
/// this contract to the bridging caller. On return to Flow EVM, the reverse process is followed - the token is locked
/// in NFT escrow and the ERC721 is transferred to the defined recipient. In this way, the Cadence token acts as a
/// representation of both the EVM NFT and thus ownership rights to it upon bridging back to Flow EVM.
///
/// To bridge between VMs, a caller can either use the interface exposed on CadenceOwnedAccount or use FlowEVMBridge
/// public contract methods.
///
access(all) contract {{CONTRACT_NAME}} : ICrossVM, IEVMBridgeNFTMinter, NonFungibleToken {

    /// Pointer to the Factory deployed Solidity contract address defining the bridged asset
    access(all) let evmNFTContractAddress: EVM.EVMAddress
    /// Name of the NFT collection defined in the corresponding ERC721 contract
    access(all) let name: String
    /// Symbol of the NFT collection defined in the corresponding ERC721 contract
    access(all) let symbol: String
    /// URI of the contract, if available as a var in case the bridge enables cross-VM Metadata syncing in the future
    access(all) var contractURI: String?
    /// Retain a Collection to reference when resolving Collection Metadata
    access(self) let collection: @Collection
    /// Mapping of token URIs indexed on their ERC721 ID. This would not normally be retained within a Cadence NFT
    /// contract, but since NFT metadata may be updated in EVM, it's retained here so that the bridge can update
    /// it against the source ERC721 contract which is treated as the NFT's source of truth.
    access(all) let tokenURIs: {UInt256: String}

    /// The NFT resource representing the bridged ERC721 token
    ///
    access(all) resource NFT : CrossVMNFT.EVMNFT {
        /// The Cadence ID of the NFT
        access(all) let id: UInt64
        /// The ERC721 ID of the NFT
        access(all) let evmID: UInt256
        /// Additional onchain metadata
        access(all) let metadata: {String: AnyStruct}

        init(
            evmID: UInt256,
            metadata: {String: AnyStruct}
        ) {
            self.id = self.uuid
            self.evmID = evmID
            self.metadata = metadata
        }

        /// Returns the metadata view types supported by this NFT
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.EVMBridgedMetadata>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
        }

        access(all) view fun getName(): String {
            return {{CONTRACT_NAME}}.name
        }

        access(all) view fun getSymbol(): String {
            return {{CONTRACT_NAME}}.symbol
        }

        access(all) view fun tokenURI(): String {
            return {{CONTRACT_NAME}}.tokenURIs[self.evmID] ?? ""
        }

        /// Resolves a metadata view for this NFT
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                // We don't know what kind of file the URI represents (IPFS v HTTP), so we can't resolve Display view
                // with the URI as thumbnail - we may a new standard view for EVM NFTs - this is interim
                case Type<MetadataViews.EVMBridgedMetadata>():
                    return MetadataViews.EVMBridgedMetadata(
                        name: self.getName(),
                        symbol: self.getSymbol(),
                        uri: MetadataViews.URI(baseURI: nil, value: self.tokenURI())
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.NFTCollectionData>():
                    return {{CONTRACT_NAME}}.resolveContractView(
                        resourceType: self.getType(),
                        viewType: Type<MetadataViews.NFTCollectionData>()
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return {{CONTRACT_NAME}}.resolveContractView(
                        resourceType: self.getType(),
                        viewType: Type<MetadataViews.NFTCollectionDisplay>()
                    )
            }
            return nil
        }

        /// public function that anyone can call to create a new empty collection
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- {{CONTRACT_NAME}}.createEmptyCollection(nftType: self.getType())
        }

        /* --- CrossVMNFT conformance --- */
        //
        /// Returns the EVM contract address of the NFT
        access(all) view fun getEVMContractAddress(): EVM.EVMAddress {
            return {{CONTRACT_NAME}}.getEVMContractAddress()
        }
    }

    /// This resource holds associated NFTs, and serves queries about stored NFTs
    access(all) resource Collection : CrossVMNFT.EVMNFTCollection {
        /// dictionary of NFT conforming tokens indexed on their ID
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}
        /// Mapping of EVM IDs to Flow NFT IDs
        access(contract) let evmIDToFlowID: {UInt256: UInt64}

        access(all) var storagePath: StoragePath
        access(all) var publicPath: PublicPath

        init () {
            self.ownedNFTs <- {}
            self.evmIDToFlowID = {}
            let collectionData = {{CONTRACT_NAME}}.resolveContractView(
                    resourceType: Type<@{{CONTRACT_NAME}}.NFT>(),
                    viewType: Type<MetadataViews.NFTCollectionData>()
                ) as! MetadataViews.NFTCollectionData?
                ?? panic("Could not resolve the collection data view for the NFT collection")
            self.storagePath = collectionData.storagePath
            self.publicPath = collectionData.publicPath
        }

        access(all) view fun getName(): String {
            return {{CONTRACT_NAME}}.name
        }

        access(all) view fun getSymbol(): String {
            return {{CONTRACT_NAME}}.symbol
        }

        /// Returns a list of NFT types that this receiver accepts
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return { Type<@{{CONTRACT_NAME}}.NFT>(): true }
        }

        /// Returns whether or not the given type is accepted by the collection
        /// A collection that can accept any type should just return true by default
        access(all) view fun isSupportedNFTType(type: Type): Bool {
           return type == Type<@{{CONTRACT_NAME}}.NFT>()
        }

        /// Removes an NFT from the collection and moves it to the caller
        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Could not withdraw an NFT with the provided ID from the collection")

            return <-token
        }

        /// Withdraws an NFT from the collection by its EVM ID
        access(NonFungibleToken.Withdraw) fun withdrawByEVMID(_ id: UInt256): @{NonFungibleToken.NFT} {
            return <- self.withdraw(withdrawID: 
                self.getCadenceID(from: id) ?? panic("Could not withdraw an NFT with the provided EVM ID from the collection")
            )
        }

        /// Ttakes a NFT and adds it to the collections dictionary and adds the ID to the evmIDToFlowID mapping
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @{{CONTRACT_NAME}}.NFT

            // add the new token to the dictionary which removes the old one
            self.evmIDToFlowID[token.evmID] = token.id
            let oldToken <- self.ownedNFTs[token.id] <- token

            destroy oldToken
        }

        /// Returns an array of the IDs that are in the collection
        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        /// Returns an array of the EVM IDs that are in the collection
        access(all) view fun getEVMIDs(): [UInt256] {
            return self.evmIDToFlowID.keys
        }

        /// Returns the Cadence NFT.id for the given EVM NFT ID if it exists in the collection
        access(all) view fun getCadenceID(from evmID: UInt256): UInt64? {
            if self.evmIDToFlowID[evmID] != nil {
                return self.evmIDToFlowID[evmID]
            } else if evmID < UInt256(UInt64.max) && self.borrowNFT(UInt64(evmID)) != nil {
                return UInt64(evmID)
            } else {
                return nil
            }
        }

        /// Returns the EVM NFT ID associated with the Cadence NFT ID. The goal is to retrieve the ERC721 ID value.
        /// As far as the bridge is concerned, an ERC721 defined by the bridge is the NFT's ID at the time of bridging
        /// or the value of the NFT.evmID if it implements the CrossVMNFT.EVMNFT interface when bridged.
        /// Following this pattern, if locked, the NFT is checked for EVMNFT conformance returning .evmID if so,
        /// otherwise the NFT's ID is returned as a UInt256 since that's how the bridge would handle minting in the
        /// corresponding ERC721 contract.
        ///
        access(all) view fun getEVMID(from cadenceID: UInt64): UInt256? {
            if let nft = self.borrowNFT(cadenceID) {
                if let evmNFT = CrossVMNFT.getEVMID(from: nft) {
                    return evmNFT
                }
                return UInt256(nft.id)
            }
            return nil
        }

        /// Returns the contractURI for the NFT collection as defined in the source ERC721 contract. If none was
        /// defined at the time of bridging, an empty string is returned.
        access(all) view fun contractURI(): String? {
            return {{CONTRACT_NAME}}.contractURI
        }

        /// Gets the amount of NFTs stored in the collection
        access(all) view fun getLength(): Int {
            return self.ownedNFTs.keys.length
        }

        /// Retrieves a reference to the NFT stored in the collection by its ID
        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        /// Borrow the view resolver for the specified NFT ID
        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            return &self.ownedNFTs[id] as &{ViewResolver.Resolver}? ?? nil
        }

        /// Creates an empty collection
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection}  {
            return <-{{CONTRACT_NAME}}.createEmptyCollection(nftType: Type<@{{CONTRACT_NAME}}.NFT>())
        }
    }

    /// createEmptyCollection creates an empty Collection for the specified NFT type
    /// and returns it to the caller so that they can own NFTs
    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    /**********************
            Getters
    ***********************/

    /// Returns the EVM contract address of the NFT this contract represents
    ///
    access(all) view fun getEVMContractAddress(): EVM.EVMAddress {
        return self.evmNFTContractAddress
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
            Type<MetadataViews.EVMBridgedMetadata>()
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
                let identifier = "{{CONTRACT_NAME}}Collection"
                let collectionData = MetadataViews.NFTCollectionData(
                    storagePath: StoragePath(identifier: identifier)!,
                    publicPath: PublicPath(identifier: identifier)!,
                    publicCollection: Type<&{{CONTRACT_NAME}}.Collection>(),
                    publicLinkedType: Type<&{{CONTRACT_NAME}}.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-{{CONTRACT_NAME}}.createEmptyCollection(nftType: Type<@{{CONTRACT_NAME}}.NFT>())
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
                    name: self.name,
                    description: "This collection was bridged from Flow EVM.",
                    externalURL: MetadataViews.ExternalURL("https://port.flow.com/"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {}
                )
            case Type<MetadataViews.EVMBridgedMetadata>():
                return MetadataViews.EVMBridgedMetadata(
                    name: self.name,
                    symbol: self.symbol,
                    uri: self.contractURI != nil ? MetadataViews.URI(baseURI: nil, value: self.contractURI!) : MetadataViews.URI(baseURI: nil, value: "")
                )
        }
        return nil
    }

    /**********************
        Internal Methods
    ***********************/

    /// Allows the bridge to mint NFTs from bridge-defined NFT contracts
    ///
    access(account)
    fun mintNFT(id: UInt256, tokenURI: String): @NFT {
        pre {
            self.tokenURIs[id] == nil: "A token with the given ERC721 ID already exists"
        }
        self.tokenURIs[id] = tokenURI
        return <-create NFT(
            evmID: id,
            metadata: {
                "Bridged Block": getCurrentBlock().height,
                "Bridged Timestamp": getCurrentBlock().timestamp
            }
        )
    }

    /// Allows the bridge to update the URI of bridged NFTs. This assumes that the EVM-defining project may contain
    /// logic (onchain or offchain) which updates NFT metadata in the source ERC721 contract. On bridging, the URI can
    /// then be updated in this contract to reflect the source ERC721 contract's metadata.
    ///
    access(account)
    fun updateTokenURI(evmID: UInt256, newURI: String) {
        pre {
            self.tokenURIs[evmID] != nil: "No token with the given ERC721 ID exists"
        }
        if self.tokenURIs[evmID] != newURI {
            self.tokenURIs[evmID] = newURI
        }
    }

    init(name: String, symbol: String, evmContractAddress: EVM.EVMAddress, contractURI: String?) {
        self.evmNFTContractAddress = evmContractAddress
        self.name = name
        self.symbol = symbol
        self.contractURI = contractURI
        self.tokenURIs = {}
        self.collection <- create Collection()

        FlowEVMBridgeConfig.associateType(Type<@{{CONTRACT_NAME}}.NFT>(), with: self.evmNFTContractAddress)
        FlowEVMBridgeNFTEscrow.initializeEscrow(
            forType: Type<@{{CONTRACT_NAME}}.NFT>(),
            name: name,
            symbol: symbol,
            erc721Address: self.evmNFTContractAddress
        )
    }
}
