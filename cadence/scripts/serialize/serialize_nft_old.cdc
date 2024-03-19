import ViewResolver from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import NonFungibleToken from 0x631e88ae7f1d7c20

/// Defines the interface for a struct that returns a serialized representation of itself
///
access(all)
struct interface SerializableStruct {
    access(all) fun serialize(): String
}

/// Method that returns a serialized representation of the given value or nil if the value is not serializable
///
access(all)
fun tryToJSONString(_ value: AnyStruct): String? {
    // Call serialize on the value if available
    if value.getType().isSubtype(of: Type<{SerializableStruct}>()) {
        return (value as! {SerializableStruct}).serialize()
    }
    // Recursively serialize array & return
    if value.getType().isSubtype(of: Type<[AnyStruct]>()) {
        return arrayToJSONString(value as! [AnyStruct])
    }
    // Recursively serialize map & return
    if value.getType().isSubtype(of: Type<{String: AnyStruct}>()) {
        return dictToJSONString(dict: value as! {String: AnyStruct}, excludedNames: nil)
    }
    // Handle primitive types & optionals
    switch value.getType() {
        case Type<Never?>():
            return "\"nil\""
        case Type<String>():
            return "\"".concat(value as! String).concat("\"")
        case Type<String?>():
            return "\"".concat(value as? String ?? "nil").concat("\"")
        case Type<Character>():
            return "\"".concat((value as! Character).toString()).concat("\"")
        case Type<Bool>():
            return "\"".concat(value as! Bool ? "true" : "false").concat("\"")
        case Type<Address>():
            return "\"".concat((value as! Address).toString()).concat("\"")
        case Type<Address?>():
            return "\"".concat((value as? Address)?.toString() ?? "nil").concat("\"")
        case Type<Int8>():
            return "\"".concat((value as! Int8).toString()).concat("\"")
        case Type<Int16>():
            return "\"".concat((value as! Int16).toString()).concat("\"")
        case Type<Int32>():
            return "\"".concat((value as! Int32).toString()).concat("\"")
        case Type<Int64>():
            return "\"".concat((value as! Int64).toString()).concat("\"")
        case Type<Int128>():
            return "\"".concat((value as! Int128).toString()).concat("\"")
        case Type<Int256>():
            return "\"".concat((value as! Int256).toString()).concat("\"")
        case Type<Int>():
            return "\"".concat((value as! Int).toString()).concat("\"")
        case Type<UInt8>():
            return "\"".concat((value as! UInt8).toString()).concat("\"")
        case Type<UInt16>():
            return "\"".concat((value as! UInt16).toString()).concat("\"")
        case Type<UInt32>():
            return "\"".concat((value as! UInt32).toString()).concat("\"")
        case Type<UInt64>():
            return "\"".concat((value as! UInt64).toString()).concat("\"")
        case Type<UInt128>():
            return "\"".concat((value as! UInt128).toString()).concat("\"")
        case Type<UInt256>():
            return "\"".concat((value as! UInt256).toString()).concat("\"")
        case Type<UInt>():
            return "\"".concat((value as! UInt).toString()).concat("\"")
        case Type<Word8>():
            return "\"".concat((value as! Word8).toString()).concat("\"")
        case Type<Word16>():
            return "\"".concat((value as! Word16).toString()).concat("\"")
        case Type<Word32>():
            return "\"".concat((value as! Word32).toString()).concat("\"")
        case Type<Word64>():
            return "\"".concat((value as! Word64).toString()).concat("\"")
        case Type<Word128>():
            return "\"".concat((value as! Word128).toString()).concat("\"")
        case Type<Word256>():
            return "\"".concat((value as! Word256).toString()).concat("\"")
        case Type<UFix64>():
            return "\"".concat((value as! UFix64).toString()).concat("\"")
        default:
            return nil
    }
}

/// Method that returns a serialized representation of the given array or nil if the value is not serializable
///
access(all)
fun arrayToJSONString(_ arr: [AnyStruct]): String? {
    var serializedArr = "["
    for i, element in arr {
        let serializedElement = tryToJSONString(element)
        if serializedElement == nil {
            return nil
        }
        serializedArr = serializedArr.concat(serializedElement!)
        if i < arr.length - 1 {
            serializedArr = serializedArr.concat(", ")
        }
    }
    return serializedArr.concat("]")
}

/// Method that returns a serialized representation of the given String-indexed mapping or nil if the value is not
/// serializable. The interface here is largely the same as as the `MetadataViews.dictToTraits` method, though here
/// a JSON-compatible String is returned instead of a `Traits` array.
///
access(all)
fun dictToJSONString(dict: {String: AnyStruct}, excludedNames: [String]?): String? {
    if excludedNames != nil {
        for k in excludedNames! {
            dict.remove(key: k)
        }
    }
    var serializedDict = "{"
    for i, key in dict.keys {
        let serializedValue = tryToJSONString(dict[key]!)
        if serializedValue == nil {
            return nil
        }
        serializedDict = serializedDict.concat(tryToJSONString(key)!).concat(": ").concat(serializedValue!)
        if i < dict.length - 1 {
            serializedDict = serializedDict.concat(", ")
        }
    }
    return serializedDict.concat("}")
}

/// Serializes the metadata (as a JSON compatible String) for a given NFT according to formats expected by EVM
/// platforms like OpenSea. If you are a project owner seeking to expose custom traits on bridged NFTs and your
/// Trait.value is not natively serializable, you can implement a custom serialization method with the
/// `{SerializableStruct}` interface's `serialize` method.
///
/// REF: https://github.com/ethereum/ercs/blob/master/ERCS/erc-721.md
/// REF: https://github.com/ethereum/ercs/blob/master/ERCS/erc-1155.md#erc-1155-metadata-uri-json-schema
/// REF: https://docs.opensea.io/docs/metadata-standards
///
access(all)
fun serializeNFTMetadata(_ nft: &{MetadataViews.Resolver}): String {
    // if nft.getType().isSubtype(of: Type<@{SerializableResource}>()) {
    //     let serializable = nft as! &{SerializableResource}
    //     return serializable.serialize()
    // }
    let display = serializeNFTDisplay(nft)
    let attributes = serializeNFTTraitsAsAttributes(nft)
    if display == nil && attributes == nil {
        return ""
    }
    var serializedMetadata= "data:application/json;utf8,{"
    if display != nil {
        serializedMetadata = serializedMetadata.concat(display!)
    }
    if display != nil && attributes != nil {
        serializedMetadata = serializedMetadata.concat(", ")
    }
    if attributes != nil {
        serializedMetadata = serializedMetadata.concat(attributes!)
    }
    return serializedMetadata.concat("}")
}

/// Serializes the display & collection display views of a given NFT as a JSON compatible string
///
access(all)
fun serializeNFTDisplay(_ nft: &{MetadataViews.Resolver}): String? {
    // Resolve Display & NFTCollection Display view, returning early if neither are found
    let nftDisplay: MetadataViews.Display? = nft.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?
    let collectionDisplay: MetadataViews.NFTCollectionDisplay? = nft.resolveView(Type<MetadataViews.NFTCollectionDisplay>()) as! MetadataViews.NFTCollectionDisplay?
    if nftDisplay == nil && collectionDisplay == nil {
        return nil
    }
    // Initialize the JSON fields
    let name = "\"name\": "
    let description = "\"description\": "
    let image = "\"image\": "
    var serializedResult = ""
    // Append results from the Display view to the serialized JSON compatible string
    if nftDisplay != nil {
        serializedResult = serializedResult.concat(name).concat(tryToJSONString(nftDisplay!.name)!).concat(", ")
            .concat(description).concat(tryToJSONString(nftDisplay!.description)!).concat(", ")
            .concat(image).concat(tryToJSONString(nftDisplay!.thumbnail.uri())!)
    }
    // Append a comma if both Display & NFTCollection Display views are present
    if nftDisplay != nil && collectionDisplay != nil {
        serializedResult = serializedResult.concat(", ")
    }
    // Serialize the external URL from the NFTCollection Display view & return
    let externalURL = "\"external_url\": "
    if collectionDisplay != nil {
        serializedResult = serializedResult.concat(externalURL).concat(tryToJSONString(collectionDisplay!.externalURL.url)!)
    }
    return serializedResult
}

/// Serializes a given NFT's Traits view as a JSON compatible string. If a given Trait is not serializable, it is
/// skipped and not included in the serialized result. If you are a project owner seeking to expose custom traits
/// on bridged NFTs and your Trait.value is not natively serializable, you can implement a custom serialization
/// method with the `{SerializableStruct}` interface's `serialize` method.
///
access(all)
fun serializeNFTTraitsAsAttributes(_ nft: &{MetadataViews.Resolver}): String? {
    // Get the Traits view from the NFT, returning early if no traits are found
    let traits = nft.resolveView(Type<MetadataViews.Traits>()) as! MetadataViews.Traits?
    if traits == nil {
        return nil
    }

    // Serialize each trait as an attribute, building the serialized JSON compatible string
    var serializedResult = "\"attributes\": ["
    for i, trait in traits!.traits {
        let value = tryToJSONString(trait.value)
        if value == nil {
            continue
        }
        serializedResult = serializedResult.concat("{")
            .concat("\"trait_type\": ").concat(tryToJSONString(trait.name)!)
            .concat(", \"value\": ").concat(value!)
            .concat("}")
        if i < traits!.traits.length - 1 {
            serializedResult = serializedResult.concat(",")
        }
    }
    return serializedResult.concat("]")
}

access(all)
fun main(address: Address, storagePathIdentifier: String, id: UInt64): String? {
    let storagePath = StoragePath(identifier: storagePathIdentifier)!
    if let collection = getAuthAccount(address).borrow<&{MetadataViews.ResolverCollection}>(from: storagePath) {
        let nft = collection.borrowViewResolver(id: id) as &{MetadataViews.Resolver}
        return serializeNFTMetadata(nft)
    }
    return nil
}
