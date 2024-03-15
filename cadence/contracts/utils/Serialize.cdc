/// This contract is a utility for serializing primitive types, arrays, and common metadata mapping formats to JSON
/// compatible strings. Also included are interfaces enabling custom serialization for structs and resources.
///
/// Special thanks to @austinkline for the idea and initial implementation.
///
access(all)
contract Serialize {

    /// Defines the interface for a struct that returns a serialized representation of itself
    ///
    access(all)
    struct interface SerializableStruct {
        access(all) fun serialize(): String
    }

    /// Defines the interface for a resource that returns a serialized representation of itself
    ///
    access(all)
    resource interface SerializableResource {
        access(all) fun serialize(): String
    }

    /// Method that returns a serialized representation of the given value or nil if the value is not serializable
    ///
    access(all)
    fun tryToString(_ value: AnyStruct): String? {
        // Call serialize on the value if available
        if value.getType().isSubtype(of: Type<{SerializableStruct}>()) {
            return (value as! {SerializableStruct}).serialize()
        }
        // Recursively serialize array & return
        if value.getType().isSubtype(of: Type<[AnyStruct]>()) {
            return self.arrayToString(value as! [AnyStruct])
        }
        // Recursively serialize map & return
        if value.getType().isSubtype(of: Type<{String: AnyStruct}>()) {
            return self.dictToString(dict: value as! {String: AnyStruct}, excludedNames: nil)
        }
        // Handle primitive types & their respective optionals
        switch value.getType() {
            case Type<Never?>():
                return "nil"
            case Type<String>():
                return value as! String
            case Type<String?>():
                return value as? String ?? "nil"
            case Type<Character>():
                return (value as! Character).toString()
            case Type<Character?>():
                return (value as? Character)?.toString() ?? "nil"
            case Type<Bool>():
                return self.boolToString(value as! Bool)
            case Type<Bool?>():
                if value as? Bool == nil {
                    return "nil"
                }
                return self.boolToString(value as! Bool)
            case Type<Address>():
                return (value as! Address).toString()
            case Type<Address?>():
                return (value as? Address)?.toString() ?? "nil"
            case Type<Int8>():
                return (value as! Int8).toString()
            case Type<Int16>():
                return (value as! Int16).toString()
            case Type<Int32>():
                return (value as! Int32).toString()
            case Type<Int64>():
                return (value as! Int64).toString()
            case Type<Int128>():
                return (value as! Int128).toString()
            case Type<Int256>():
                return (value as! Int256).toString()
            case Type<Int>():
                return (value as! Int).toString()
            case Type<UInt8>():
                return (value as! UInt8).toString()
            case Type<UInt16>():
                return (value as! UInt16).toString()
            case Type<UInt32>():
                return (value as! UInt32).toString()
            case Type<UInt64>():
                return (value as! UInt64).toString()
            case Type<UInt128>():
                return (value as! UInt128).toString()
            case Type<UInt256>():
                return (value as! UInt256).toString()
            case Type<UInt>():
                return (value as! UInt).toString()
            case Type<Word8>():
                return (value as! Word8).toString()
            case Type<Word16>():
                return (value as! Word16).toString()
            case Type<Word32>():
                return (value as! Word32).toString()
            case Type<Word64>():
                return (value as! Word64).toString()
            case Type<Word128>():
                return (value as! Word128).toString()
            case Type<Word256>():
                return (value as! Word256).toString()
            case Type<UFix64>():
                return (value as! UFix64).toString()
            default:
                return nil
        }
    }

    access(all)
    fun tryToJSONString(_ value: AnyStruct): String? {
        return "\"".concat(self.tryToString(value) ?? "nil").concat("\"")
    }

    /// Method that returns a serialized representation of a provided boolean
    ///
    access(all)
    fun boolToString(_ value: Bool): String {
        return value ? "true" : "false"
    }

    /// Method that returns a serialized representation of the given array or nil if the value is not serializable
    ///
    access(all)
    fun arrayToString(_ arr: [AnyStruct]): String? {
        var serializedArr = "["
        for i, element in arr {
            let serializedElement = self.tryToString(element)
            if serializedElement == nil {
                return nil
            }
            serializedArr = serializedArr.concat("\"").concat(serializedElement!).concat("\"")
            if i < arr.length - 1 {
                serializedArr = serializedArr.concat(", ")
            }
        }
        serializedArr.concat("]")
        return serializedArr
    }

    /// Method that returns a serialized representation of the given String-indexed mapping or nil if the value is not
    /// serializable. The interface here is largely the same as as the `MetadataViews.dictToTraits` method, though here
    /// a JSON-compatible String is returned instead of a `Traits` array.
    ///
    access(all)
    fun dictToString(dict: {String: AnyStruct}, excludedNames: [String]?): String? {
        if excludedNames != nil {
            for k in excludedNames! {
                dict.remove(key: k)
            }
        }
        var serializedDict = "{"
        for i, key in dict.keys {
            let serializedValue = self.tryToString(dict[key]!)
            if serializedValue == nil {
                return nil
            }
            serializedDict = serializedDict.concat("\"").concat(key).concat("\": \"").concat(serializedValue!).concat("\"}")
            if i < dict.length - 1 {
                serializedDict = serializedDict.concat(", ")
            }
        }
        serializedDict.concat("}")
        return serializedDict
    }
}
