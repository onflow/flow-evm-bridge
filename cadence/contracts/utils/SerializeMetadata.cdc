import "ViewResolver"
import "MetadataViews"
import "NonFungibleToken"
import "FungibleTokenMetadataViews"

import "Serialize"

/// This contract defines methods for serializing NFT metadata as a JSON compatible string, according to the common
/// OpenSea metadata format. NFTs and metadata views can be serialized by reference via contract methods.
///
/// Special thanks to @austinkline for the idea and initial implementation & @bjartek + @bluesign for optimizations.
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
        // Serialize the display & collection display views - nil if both views are nil
        let display = self.serializeFromDisplays(nftDisplay: nftDisplay, collectionDisplay: collectionDisplay)

        // Get the Traits view from the NFT, returning early if no traits are found
        let traits = nft.resolveView(Type<MetadataViews.Traits>()) as! MetadataViews.Traits?
        let attributes = self.serializeNFTTraitsAsAttributes(traits ?? MetadataViews.Traits([]))

        // Return an empty string if all views are nil
        if display == nil && traits == nil {
            return ""
        }
        // Init the data format prefix & concatenate the serialized display & attributes
        let parts: [String] = ["data:application/json;utf8,{"]
        if display != nil {
            parts.appendAll([display!, ", "]) // Include display if present & separate with a comma
        }
        parts.appendAll([attributes, "}"]) // Include attributes & close the JSON object

        return String.join(parts, separator: "")
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
        let parts: [String] = []

        // Append results from the token-level Display view to the serialized JSON compatible string
        if nftDisplay != nil {
            parts.appendAll([
                name, Serialize.tryToJSONString(nftDisplay!.name)!, ", ",
                description, Serialize.tryToJSONString(nftDisplay!.description)!, ", ",
                image, Serialize.tryToJSONString(nftDisplay!.thumbnail.uri())!
            ])
            // Append the `external_url` value from NFTCollectionDisplay view if present
            if collectionDisplay != nil {
                parts.appendAll([", ", externalURL, Serialize.tryToJSONString(collectionDisplay!.externalURL.url)!])
                return String.join(parts, separator: "")
            }
        }

        if collectionDisplay == nil {
            return String.join(parts, separator: "")
        }

        // Without token-level view, serialize as contract-level metadata
        parts.appendAll([
            name, Serialize.tryToJSONString(collectionDisplay!.name)!, ", ",
            description, Serialize.tryToJSONString(collectionDisplay!.description)!, ", ",
            image, Serialize.tryToJSONString(collectionDisplay!.squareImage.file.uri())!, ", ",
            externalLink, Serialize.tryToJSONString(collectionDisplay!.externalURL.url)!
        ])
        return String.join(parts, separator: "")
    }

    /// Serializes given Traits view as a JSON compatible string. If a given Trait is not serializable, it is skipped
    /// and not included in the serialized result.
    ///
    /// @param traits: The Traits view to be serialized
    ///
    /// @returns: A JSON compatible string containing the serialized traits as follows
    ///     (display_type omitted if trait.displayType == nil):
    ///     `\"attributes\": [{\"trait_type\": \"<trait.name>\", \"display_type\": \"<trait.displayType>\", \"value\": \"<trait.value>\"}, {...}]`
    ///
    access(all)
    fun serializeNFTTraitsAsAttributes(_ traits: MetadataViews.Traits): String {
        // Serialize each trait as an attribute, building the serialized JSON compatible string
        let parts: [String] = []
        let traitsLength = traits.traits.length
        for trait in traits.traits {
            let attribute = self.serializeNFTTraitAsAttribute(trait)
            if attribute == nil {
                continue
            }
            parts.append(attribute!)
        }
        // Join all serialized attributes with a comma separator, wrapping the result in square brackets under the
        // `attributes` key
        return "\"attributes\": [".concat(String.join(parts, separator: ", ")).concat("]")
    }

    /// Serializes a given Trait as an attribute in a JSON compatible format. If the trait's value is not serializable,
    /// nil is returned.
    /// The format of the serialized trait is as follows (display_type omitted if trait.displayType == nil):
    ///     `{"trait_type": "<trait.name>", "display_type": "<trait.displayType>", "value": "<trait.value>"}`
    access(all)
    fun serializeNFTTraitAsAttribute(_ trait: MetadataViews.Trait): String? {
        let value = Serialize.tryToJSONString(trait.value)
        if value == nil {
            return nil
        }
        let parts: [String] = ["{"]
        parts.appendAll( [ "\"trait_type\": ", Serialize.tryToJSONString(trait.name)! ] )
        if trait.displayType != nil {
            parts.appendAll( [ ", \"display_type\": ", Serialize.tryToJSONString(trait.displayType)! ] )
        }
        parts.appendAll( [ ", \"value\": ", value! , "}" ] )
        return String.join(parts, separator: "")
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
        let parts: [String] = ["data:application/json;utf8,{"]

        parts.appendAll([
            name, Serialize.tryToJSONString(ftDisplay.name)!, ", ",
            symbol, Serialize.tryToJSONString(ftDisplay.symbol)!, ", ",
            description, Serialize.tryToJSONString(ftDisplay.description)!, ", ",
            externalLink, Serialize.tryToJSONString(ftDisplay.externalURL.url)!
        ])
        return String.join(parts, separator: "")
    }

    /// Derives a symbol for use as an ERC20 or ERC721 symbol from a given string, presumably a Cadence contract name.
    /// Derivation is a process of slicing the first 4 characters of the string and converting them to uppercase.
    ///
    /// @param fromString: The string from which to derive a symbol
    ///
    /// @returns: A derived symbol for use as an ERC20 or ERC721 symbol based on the provided string, presumably a
    ///    Cadence contract name
    ///
    access(all) view fun deriveSymbol(fromString: String): String {
        let defaultLen = 4
        let len = fromString.length < defaultLen ? fromString.length : defaultLen
        return self.toUpperAlphaNumerical(fromString, upTo: len)
    }

    /// Returns the uppercase alphanumeric version of a given string. If upTo is nil or exceeds the length of the string,
    /// the entire string is converted to uppercase.
    ///
    /// @param str: The string to convert to uppercase
    /// @param upTo: The maximum number of characters to convert to uppercase
    ///
    /// @returns: The uppercase version of the given string
    ///
    access(all) view fun toUpperAlphaNumerical(_ str: String, upTo: Int?): String {
        let len = upTo ?? str.length
        var upper: String = ""
        for char in str {
            if upper.length == len {
                break
            }
            let bytes = char.utf8
            if bytes.length != 1 {
                continue
            }
            let byte = bytes[0]
            if byte >= 97 && byte <= 122 {
                // Convert lower case to upper case
                let upperChar = String.fromUTF8([byte - UInt8(32)])!
                upper = upper.concat(upperChar)
            } else if byte >= 65 && byte <= 90 {
                // Keep upper case
                upper = upper.concat(char.toString())
            } else if byte >= 48 && byte <= 57 {
                // Keep numbers
                upper = upper.concat(String.fromCharacters([char]))
            } else {
                // Skip non-alphanumeric characters
                continue
            }
        }
        return upper
    }
}
