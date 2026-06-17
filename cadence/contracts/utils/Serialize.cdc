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
                return "\"\(self.escapeJSONString(value as! String))\""
            case Type<String?>():
                return "\"\(self.escapeJSONString(value as? String ?? "nil"))\""
            case Type<Character>():
                return "\"\(self.escapeJSONString((value as! Character).toString()))\""
            case Type<Bool>():
                return "\"\(value as! Bool ? "true" : "false")\""
            case Type<Address>():
                return "\"\((value as! Address).toString())\""
            case Type<Address?>():
                return "\"\((value as? Address)?.toString() ?? "nil")\""
            case Type<Int8>():
                return "\"\((value as! Int8).toString())\""
            case Type<Int16>():
                return "\"\((value as! Int16).toString())\""
            case Type<Int32>():
                return "\"\((value as! Int32).toString())\""
            case Type<Int64>():
                return "\"\((value as! Int64).toString())\""
            case Type<Int128>():
                return "\"\((value as! Int128).toString())\""
            case Type<Int256>():
                return "\"\((value as! Int256).toString())\""
            case Type<Int>():
                return "\"\((value as! Int).toString())\""
            case Type<UInt8>():
                return "\"\((value as! UInt8).toString())\""
            case Type<UInt16>():
                return "\"\((value as! UInt16).toString())\""
            case Type<UInt32>():
                return "\"\((value as! UInt32).toString())\""
            case Type<UInt64>():
                return "\"\((value as! UInt64).toString())\""
            case Type<UInt128>():
                return "\"\((value as! UInt128).toString())\""
            case Type<UInt256>():
                return "\"\((value as! UInt256).toString())\""
            case Type<UInt>():
                return "\"\((value as! UInt).toString())\""
            case Type<Word8>():
                return "\"\((value as! Word8).toString())\""
            case Type<Word16>():
                return "\"\((value as! Word16).toString())\""
            case Type<Word32>():
                return "\"\((value as! Word32).toString())\""
            case Type<Word64>():
                return "\"\((value as! Word64).toString())\""
            case Type<Word128>():
                return "\"\((value as! Word128).toString())\""
            case Type<Word256>():
                return "\"\((value as! Word256).toString())\""
            case Type<UFix64>():
                return "\"\((value as! UFix64).toString())\""
            default:
                return nil
        }
    }

    /// Escapes a string for inclusion in a JSON string literal.
    /// Backslash, double quote, and control characters U+0000 through U+001F are escaped per
    /// RFC 8259 Section 7. Additionally, the HTML-significant characters `<`, `>`, `&` and the
    /// U+2028 / U+2029 line/paragraph separators are escaped defensively: the metadata is often
    /// rendered in browsers, where `<`, `>`, `&` enable XSS and U+2028 / U+2029 are invalid in
    /// JavaScript string literals. All escapes are valid JSON, so parsers recover the original text.
    /// All other characters, including multi-byte UTF-8 sequences, pass through unchanged.
    ///
    access(all)
    fun escapeJSONString(_ str: String): String {
        let bytes = str.utf8
        // Fast path: return unchanged if nothing needs escaping (the common case)
        var needsEscaping = false
        var i = 0
        while i < bytes.length {
            let b = bytes[i]
            if b == 0x22 || b == 0x5C || b == 0x3C || b == 0x3E || b == 0x26 || b < 0x20 {
                needsEscaping = true
                break
            }
            // U+2028 / U+2029 are encoded as E2 80 A8 / E2 80 A9 in UTF-8
            if b == 0xE2 && i + 2 < bytes.length && bytes[i + 1] == 0x80
                && (bytes[i + 2] == 0xA8 || bytes[i + 2] == 0xA9) {
                needsEscaping = true
                break
            }
            i = i + 1
        }
        if !needsEscaping {
            return str
        }

        let hexDigits = "0123456789abcdef"
        let builder = StringBuilder()
        for char in str {
            // A character that needs escaping is either a single-byte ASCII character or one of the
            // multi-byte separators handled below; everything else is appended verbatim.
            let cb = char.toString().utf8
            if cb.length == 1 {
                let b = cb[0]
                switch b {
                    case 0x22:
                        builder.append("\\\"") // \"
                    case 0x5C:
                        builder.append("\\\\") // \\
                    case 0x08:
                        builder.append("\\b")
                    case 0x09:
                        builder.append("\\t")
                    case 0x0A:
                        builder.append("\\n")
                    case 0x0C:
                        builder.append("\\f")
                    case 0x0D:
                        builder.append("\\r")
                    case 0x3C:
                        builder.append("\\u003c") // <
                    case 0x3E:
                        builder.append("\\u003e") // >
                    case 0x26:
                        builder.append("\\u0026") // &
                    default:
                        if b < 0x20 {
                            // Escape remaining control characters as \u00XX with lowercase hex digits
                            let high = b < 0x10 ? "0" : "1"
                            let low = hexDigits[Int(b % 16)].toString()
                            builder.append("\\u00\(high)\(low)")
                        } else {
                            builder.appendCharacter(char)
                        }
                }
            } else if cb.length == 3 && cb[0] == 0xE2 && cb[1] == 0x80 && cb[2] == 0xA8 {
                builder.append("\\u2028") // U+2028 LINE SEPARATOR
            } else if cb.length == 3 && cb[0] == 0xE2 && cb[1] == 0x80 && cb[2] == 0xA9 {
                builder.append("\\u2029") // U+2029 PARAGRAPH SEPARATOR
            } else {
                // All other characters pass through, including multi-byte UTF-8 sequences
                builder.appendCharacter(char)
            }
        }
        return builder.toString()
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
        return "[\(String.join(parts, separator: ", "))]"
    }

    /// Returns a serialized representation of the given String-indexed mapping or nil if the value is not serializable.
    /// The interface here is largely the same as as the `MetadataViews.dictToTraits` method, though here
    /// a JSON-compatible String is returned instead of a `Traits` array.
    ///
    access(all)
    fun dictToJSONString(dict: {String: AnyStruct}, excludedNames: [String]?): String? {
        if let excludedNames = excludedNames {
            for k in excludedNames {
                dict.remove(key: k)
            }
        }
        let parts: [String] = []
        for key in dict {
            let serializedValue = self.tryToJSONString(dict[key]!)
            if serializedValue == nil {
                continue
            }
            let serialializedKeyValue = "\(self.tryToJSONString(key)!): \(serializedValue!)"
            parts.append(serialializedKeyValue)
        }
        return "{\(String.join(parts, separator: ", "))}"
    }
}
