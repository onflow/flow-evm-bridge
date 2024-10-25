import "ViewResolver"
import "MetadataViews"
import "NonFungibleToken"

/// This contract is a utility for serializing primitive types, arrays, and common metadata mapping formats to JSON
/// compatible strings. Also included are interfaces enabling custom serialization for structs and resources.
///
/// Special thanks to @austinkline for the idea and initial implementation & @bjartek + @bluesign for optimizations.
///
access(all)
contract Serialize {

    /// Method that returns a serialized representation of the given value or nil if the value is not serializable
    ///
    access(all)
    fun tryToJSONString(_ value: AnyStruct): String? {
        // Recursively serialize array & return
        if value.getType().isSubtype(of: Type<[AnyStruct]>()) {
            return self.arrayToJSONString(value as! [AnyStruct])
        }
        // Recursively serialize map & return
        if value.getType().isSubtype(of: Type<{String: AnyStruct}>()) {
            return self.dictToJSONString(dict: value as! {String: AnyStruct}, excludedNames: nil)
        }
        // Handle primitive types & optionals
        switch value.getType() {
            case Type<Never?>():
                return "\"nil\""
            case Type<String>():
                return String.join(["\"", value as! String, "\"" ], separator: "")
            case Type<String?>():
                return String.join(["\"", value as? String ?? "nil", "\"" ], separator: "")
            case Type<Character>():
                return String.join(["\"", (value as! Character).toString(), "\"" ], separator: "")
            case Type<Bool>():
                return String.join(["\"", value as! Bool ? "true" : "false", "\"" ], separator: "")
            case Type<Address>():
                return String.join(["\"", (value as! Address).toString(), "\"" ], separator: "")
            case Type<Address?>():
                return String.join(["\"", (value as? Address)?.toString() ?? "nil", "\"" ], separator: "")
            case Type<Int8>():
                return String.join(["\"", (value as! Int8).toString(), "\"" ], separator: "")
            case Type<Int16>():
                return String.join(["\"", (value as! Int16).toString(), "\"" ], separator: "")
            case Type<Int32>():
                return String.join(["\"", (value as! Int32).toString(), "\"" ], separator: "")
            case Type<Int64>():
                return String.join(["\"", (value as! Int64).toString(), "\"" ], separator: "")
            case Type<Int128>():
                return String.join(["\"", (value as! Int128).toString(), "\"" ], separator: "")
            case Type<Int256>():
                return String.join(["\"", (value as! Int256).toString(), "\"" ], separator: "")
            case Type<Int>():
                return String.join(["\"", (value as! Int).toString(), "\"" ], separator: "")
            case Type<UInt8>():
                return String.join(["\"", (value as! UInt8).toString(), "\"" ], separator: "")
            case Type<UInt16>():
                return String.join(["\"", (value as! UInt16).toString(), "\"" ], separator: "")
            case Type<UInt32>():
                return String.join(["\"", (value as! UInt32).toString(), "\"" ], separator: "")
            case Type<UInt64>():
                return String.join(["\"", (value as! UInt64).toString(), "\"" ], separator: "")
            case Type<UInt128>():
                return String.join(["\"", (value as! UInt128).toString(), "\"" ], separator: "")
            case Type<UInt256>():
                return String.join(["\"", (value as! UInt256).toString(), "\"" ], separator: "")
            case Type<UInt>():
                return String.join(["\"", (value as! UInt).toString(), "\"" ], separator: "")
            case Type<Word8>():
                return String.join(["\"", (value as! Word8).toString(), "\"" ], separator: "")
            case Type<Word16>():
                return String.join(["\"", (value as! Word16).toString(), "\"" ], separator: "")
            case Type<Word32>():
                return String.join(["\"", (value as! Word32).toString(), "\"" ], separator: "")
            case Type<Word64>():
                return String.join(["\"", (value as! Word64).toString(), "\"" ], separator: "")
            case Type<Word128>():
                return String.join(["\"", (value as! Word128).toString(), "\"" ], separator: "")
            case Type<Word256>():
                return String.join(["\"", (value as! Word256).toString(), "\"" ], separator: "")
            case Type<UFix64>():
                return String.join(["\"", (value as! UFix64).toString(), "\"" ], separator: "")
            default:
                return nil
        }
    }

    /// Returns a serialized representation of the given array or nil if the value is not serializable
    ///
    access(all)
    fun arrayToJSONString(_ arr: [AnyStruct]): String? {
        let parts: [String]= []
        for element in arr {
            let serializedElement = self.tryToJSONString(element)
            if serializedElement == nil {
                continue
            }
            parts.append(serializedElement!)
        }
        return "[".concat(String.join(parts, separator: ", ")).concat("]")
    }

    /// Returns a serialized representation of the given String-indexed mapping or nil if the value is not serializable.
    /// The interface here is largely the same as as the `MetadataViews.dictToTraits` method, though here
    /// a JSON-compatible String is returned instead of a `Traits` array.
    ///
    access(all)
    fun dictToJSONString(dict: {String: AnyStruct}, excludedNames: [String]?): String? {
        if excludedNames != nil {
            for k in excludedNames! {
                dict.remove(key: k)
            }
        }
        let parts: [String] = []
        for key in dict.keys {
            let serializedValue = self.tryToJSONString(dict[key]!)
            if serializedValue == nil {
                continue
            }
            let serialializedKeyValue = String.join([self.tryToJSONString(key)!, serializedValue!], separator: ": ")
            parts.append(serialializedKeyValue)
        }
        return "{".concat(String.join(parts, separator: ", ")).concat("}")
    }
}
