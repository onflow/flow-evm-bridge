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
                return String.join(["\"", self.escapeJSONString(value as! String), "\"" ], separator: "")
            case Type<String?>():
                return String.join(["\"", self.escapeJSONString(value as? String ?? "nil"), "\"" ], separator: "")
            case Type<Character>():
                return String.join(["\"", self.escapeJSONString((value as! Character).toString()), "\"" ], separator: "")
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

    /// Escapes a string for inclusion in a JSON string literal per RFC 8259 Section 7, escaping backslash,
    /// double quote, and control characters U+0000 through U+001F. All other characters, including multi-byte
    /// UTF-8 sequences, pass through unchanged.
    ///
    access(all)
    fun escapeJSONString(_ str: String): String {
        let bytes = str.utf8
        // Fast path: return unchanged if nothing needs escaping (the common case)
        var needsEscaping = false
        for b in bytes {
            if b == 0x22 || b == 0x5C || b < 0x20 {
                needsEscaping = true
                break
            }
        }
        if !needsEscaping {
            return str
        }

        let out: [UInt8] = []
        for b in bytes {
            switch b {
                case 0x22:
                    out.appendAll([0x5C, 0x22]) // \"
                case 0x5C:
                    out.appendAll([0x5C, 0x5C]) // \\
                case 0x08:
                    out.appendAll([0x5C, 0x62]) // \b
                case 0x09:
                    out.appendAll([0x5C, 0x74]) // \t
                case 0x0A:
                    out.appendAll([0x5C, 0x6E]) // \n
                case 0x0C:
                    out.appendAll([0x5C, 0x66]) // \f
                case 0x0D:
                    out.appendAll([0x5C, 0x72]) // \r
                default:
                    if b < 0x20 {
                        // Escape remaining control characters as \u00XX with lowercase hex digits
                        let low = b % 16
                        out.appendAll([0x5C, 0x75, 0x30, 0x30]) // \u00
                        out.append(b < 0x10 ? 0x30 : 0x31) // '0' or '1'
                        out.append(low < 10 ? 0x30 + low : 0x57 + low) // '0'-'9' or 'a'-'f'
                    } else {
                        // All other bytes pass through, including multi-byte UTF-8 sequences (>= 0x80)
                        out.append(b)
                    }
            }
        }
        return String.fromUTF8(out)
            ?? panic("Serialize.escapeJSONString: failed to re-encode escaped UTF-8 bytes")
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
