import "ViewResolver"
import "MetadataViews"
import "NonFungibleToken"
import "FungibleTokenMetadataViews"

import "Serialize"

/// This contract defines methods for serializing NFT metadata as a JSON compatible string, according to the common
/// OpenSea metadata format. NFTs and metadata views can be serialized by reference via contract methods.
///
access(all) contract SerializeMetadata {

    /// Serializes the metadata (as a JSON compatible String) for a given NFT according to formats expected by EVM
    /// platforms like OpenSea. If you are a project owner seeking to expose custom traits on bridged NFTs and your
    /// Trait.value is not natively serializable, you can implement a custom serialization method with the
    /// `{SerializableStruct}` interface's `serialize` method.
    ///
    /// Reference: https://docs.opensea.io/docs/metadata-standards
    ///
    ///
    /// @returns: A JSON compatible data URL string containing the serialized display & collection display views as:
    ///     `data:application/json;utf8,{
    ///         \"name\": \"<display.name>\",
    ///         \"description\": \"<display.description>\",
    ///         \"image\": \"<display.thumbnail.uri()>\",
    ///         \"external_url\": \"<nftCollectionDisplay.externalURL.url>\",
    ///         \"attributes\": [{\"trait_type\": \"<trait.name>\", \"value\": \"<trait.value>\"}, {...}]
    ///     }`
    access(all)
    fun serializeNFTMetadataAsURI(_ nft: &{NonFungibleToken.NFT}): String {
        // Serialize the display values from the NFT's Display & NFTCollectionDisplay views
        let nftDisplay = nft.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?
        let collectionDisplay = nft.resolveView(Type<MetadataViews.NFTCollectionDisplay>()) as! MetadataViews.NFTCollectionDisplay?
        let display = self.serializeFromDisplays(nftDisplay: nftDisplay, collectionDisplay: collectionDisplay)

        // Get the Traits view from the NFT, returning early if no traits are found
        let traits = nft.resolveView(Type<MetadataViews.Traits>()) as! MetadataViews.Traits?
        let attributes = self.serializeNFTTraitsAsAttributes(traits ?? MetadataViews.Traits([]))

        // Return an empty string if nothing is serializable
        if display == nil && attributes == nil {
            return ""
        }
        // Init the data format prefix & concatenate the serialized display & attributes
        var serializedMetadata = "data:application/json;utf8,{"
        if display != nil {
            serializedMetadata = serializedMetadata.concat(display!)
        }
        if display != nil && attributes != nil {
            serializedMetadata = serializedMetadata.concat(", ")
        }
        if attributes != nil {
            serializedMetadata = serializedMetadata.concat(attributes)
        }
        return serializedMetadata.concat("}")
    }

    /// Serializes the display & collection display views of a given NFT as a JSON compatible string. If nftDisplay is 
    /// present, the value is returned as token-level metadata. If nftDisplay is nil and collectionDisplay is present,
    /// the value is returned as contract-level metadata. If both values are nil, nil is returned.
    ///
    /// @param nftDisplay: The NFT's Display view from which values `name`, `description`, and `thumbnail` are serialized
    /// @param collectionDisplay: The NFT's NFTCollectionDisplay view from which the `externalURL` is serialized
    ///
    /// @returns: A JSON compatible string containing the serialized display & collection display views as either:
    ///         \"name\": \"<nftDisplay.name>\", \"description\": \"<nftDisplay.description>\", \"image\": \"<nftDisplay.thumbnail.uri()>\", \"external_url\": \"<collectionDisplay.externalURL.url>\",
    ///         \"name\": \"<collectionDisplay.name>\", \"description\": \"<collectionDisplay.description>\", \"image\": \"<collectionDisplay.squareImage.file.uri()>\", \"external_link\": \"<collectionDisplay.externalURL.url>\",
    ///
    access(all)
    fun serializeFromDisplays(nftDisplay: MetadataViews.Display?, collectionDisplay: MetadataViews.NFTCollectionDisplay?): String? {
        // Return early if both values are nil
        if nftDisplay == nil && collectionDisplay == nil {
            return nil
        }

        // Initialize JSON fields
        let name = "\"name\": "
        let description = "\"description\": "
        let image = "\"image\": "
        let externalURL = "\"external_url\": "
        let externalLink = "\"external_link\": "
        var serializedResult = ""

        // Append results from the token-level Display view to the serialized JSON compatible string
        if nftDisplay != nil {
            serializedResult = serializedResult
                .concat(name).concat(Serialize.tryToJSONString(nftDisplay!.name)!).concat(", ")
                .concat(description).concat(Serialize.tryToJSONString(nftDisplay!.description)!).concat(", ")
                .concat(image).concat(Serialize.tryToJSONString(nftDisplay!.thumbnail.uri())!)
            // Append the `externa_url` value from NFTCollectionDisplay view if present
            if collectionDisplay != nil {
                return serializedResult.concat(", ")
                    .concat(externalURL).concat(Serialize.tryToJSONString(collectionDisplay!.externalURL.url)!)
            }
        }

        if collectionDisplay == nil {
            return serializedResult
        }

        // Without token-level view, serialize as contract-level metadata
        return serializedResult
            .concat(name).concat(Serialize.tryToJSONString(collectionDisplay!.name)!).concat(", ")
            .concat(description).concat(Serialize.tryToJSONString(collectionDisplay!.description)!).concat(", ")
            .concat(image).concat(Serialize.tryToJSONString(collectionDisplay!.squareImage.file.uri())!).concat(", ")
            .concat(externalLink).concat(Serialize.tryToJSONString(collectionDisplay!.externalURL.url)!)
    }

    /// Serializes given Traits view as a JSON compatible string. If a given Trait is not serializable, it is skipped
    /// and not included in the serialized result.
    ///
    /// @param traits: The Traits view to be serialized
    ///
    /// @returns: A JSON compatible string containing the serialized traits as:
    ///     `\"attributes\": [{\"trait_type\": \"<trait.name>\", \"value\": \"<trait.value>\"}, {...}]`
    ///
    access(all)
    fun serializeNFTTraitsAsAttributes(_ traits: MetadataViews.Traits): String {
        // Serialize each trait as an attribute, building the serialized JSON compatible string
        var serializedResult = "\"attributes\": ["
        for i, trait in traits!.traits {
            let value = Serialize.tryToJSONString(trait.value)
            if value == nil {
                continue
            }
            serializedResult = serializedResult.concat("{")
                .concat("\"trait_type\": ").concat(Serialize.tryToJSONString(trait.name)!)
                .concat(", \"value\": ").concat(value!)
                .concat("}")
            if i < traits!.traits.length - 1 {
                serializedResult = serializedResult.concat(",")
            }
        }
        return serializedResult.concat("]")
    }

    /// Serializes the FTDisplay view of a given fungible token as a JSON compatible data URL. The value is returned as 
    /// contract-level metadata.
    ///
    /// @param ftDisplay: The tokens's FTDisplay view from which values `name`, `symbol`, `description`, and 
    ///     `externaURL` are serialized
    ///
    /// @returns: A JSON compatible data URL string containing the serialized view as:
    ///     `data:application/json;utf8,{
    ///         \"name\": \"<ftDisplay.name>\",
    ///         \"symbol\": \"<ftDisplay.symbol>\",
    ///         \"description\": \"<ftDisplay.description>\",
    ///         \"external_link\": \"<ftDisplay.externalURL.url>\",
    ///     }`
    access(all)
    fun serializeFTDisplay(_ ftDisplay: FungibleTokenMetadataViews.FTDisplay): String {
        let name = "\"name\": "
        let symbol = "\"symbol\": "
        let description = "\"description\": "
        let externalLink = "\"external_link\": "

        return "data:application/json;utf8,{"
            .concat(name).concat(Serialize.tryToJSONString(ftDisplay.name)!).concat(", ")
            .concat(symbol).concat(Serialize.tryToJSONString(ftDisplay.symbol)!).concat(", ")
            .concat(description).concat(Serialize.tryToJSONString(ftDisplay.description)!).concat(", ")
            .concat(externalLink).concat(Serialize.tryToJSONString(ftDisplay.externalURL.url)!)
            .concat("}")
    }
}