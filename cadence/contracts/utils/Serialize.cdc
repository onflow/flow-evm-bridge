import "ViewResolver"
import "MetadataViews"
import "NonFungibleToken"

/// This contract is a utility for serializing primitive types, arrays, and common metadata mapping formats to JSON
/// compatible strings. Also included are interfaces enabling custom serialization for structs and resources.
///
/// Special thanks to @austinkline for the idea and initial implementation.
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

    /// Returns a serialized representation of the given array or nil if the value is not serializable
    ///
    access(all)
    fun arrayToJSONString(_ arr: [AnyStruct]): String? {
        var serializedArr = "["
        let arrLength = arr.length
        for i, element in arr {
            let serializedElement = self.tryToJSONString(element)
            if serializedElement == nil {
                if i == arrLength - 1 && serializedArr.length > 1 && serializedArr[serializedArr.length - 2] == "," {
                    // Remove trailing comma as this element could not be serialized
                    serializedArr = serializedArr.slice(from: 0, upTo: serializedArr.length - 2)
                }
                continue
            }
            serializedArr = serializedArr.concat(serializedElement!)
            // Add a comma if there are more elements to serialize
            if i < arr.length - 1 {
                serializedArr = serializedArr.concat(", ")
            }
        }
        return serializedArr.concat("]")
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
        var serializedDict = "{"
        let dictLength = dict.length
        for i, key in dict.keys {
            let serializedValue = self.tryToJSONString(dict[key]!)
            if serializedValue == nil {
                if i == dictLength - 1  && serializedDict.length > 1 && serializedDict[serializedDict.length - 2] == "," {
                    // Remove trailing comma as this element could not be serialized
                    serializedDict = serializedDict.slice(from: 0, upTo: serializedDict.length - 2)
                }
                continue
            }
            serializedDict = serializedDict.concat(self.tryToJSONString(key)!).concat(": ").concat(serializedValue!)
            if i < dict.length - 1 {
                serializedDict = serializedDict.concat(", ")
            }
        }
        return serializedDict.concat("}")
    }
}
