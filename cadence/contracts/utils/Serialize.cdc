import "ViewResolver"
import "MetadataViews"
import "NonFungibleToken"

/// This contract is a utility for serializing primitive types, arrays, and common metadata mapping formats to JSON
/// compatible strings. Also included are interfaces enabling custom serialization for structs and resources.
///
/// Special thanks to @austinkline for the idea and initial implementation & @bjartek + @bluesign for optimizations.
///
/// Serialization is performed against a single shared `StringBuilder` to avoid allocating and concatenating
/// intermediate strings: the public functions create a builder and delegate to the private `*JSONString` helpers,
/// which append directly to it.
///
access(all)
contract Serialize {

    /// Returns a serialized representation of the given value or nil if the value is not serializable.
    ///
    access(all)
    fun tryToJSONString(_ value: AnyStruct): String? {
        let builder = StringBuilder()
        if self.appendJSONString(value, to: builder, prefix: "") {
            return builder.toString()
        }
        return nil
    }

    /// Appends a serialized representation of the given value to `builder`, preceded by `prefix`, or nothing
    /// (not even `prefix`) if the value is not serializable. Returns whether anything was appended, so that
    /// callers can use `prefix` to emit separators only for serializable entries.
    ///
    access(self)
    fun appendJSONString(_ value: AnyStruct, to builder: StringBuilder, prefix: String): Bool {
        let type = value.getType()
        // Recursively serialize arrays & maps
        if type.isSubtype(of: Type<[AnyStruct]>()) {
            builder.append(prefix)
            self.appendArrayJSONString(value as! [AnyStruct], to: builder)
            return true
        }
        if type.isSubtype(of: Type<{String: AnyStruct}>()) {
            builder.append(prefix)
            self.appendDictJSONString(dict: value as! {String: AnyStruct}, excludedNames: nil, to: builder)
            return true
        }
        // Handle primitive types & optionals. String-like values are escaped; all others are appended verbatim
        // between quotes.
        switch type {
            case Type<Never?>():
                self.appendQuoted(prefix, "nil", to: builder)
            case Type<String>():
                self.appendQuotedEscaped(prefix, value as! String, to: builder)
            case Type<String?>():
                self.appendQuotedEscaped(prefix, value as? String ?? "nil", to: builder)
            case Type<Character>():
                self.appendQuotedEscaped(prefix, (value as! Character).toString(), to: builder)
            case Type<Bool>():
                self.appendQuoted(prefix, value as! Bool ? "true" : "false", to: builder)
            case Type<Address>():
                self.appendQuoted(prefix, (value as! Address).toString(), to: builder)
            case Type<Address?>():
                self.appendQuoted(prefix, (value as? Address)?.toString() ?? "nil", to: builder)
            case Type<Int8>():
                self.appendQuoted(prefix, (value as! Int8).toString(), to: builder)
            case Type<Int16>():
                self.appendQuoted(prefix, (value as! Int16).toString(), to: builder)
            case Type<Int32>():
                self.appendQuoted(prefix, (value as! Int32).toString(), to: builder)
            case Type<Int64>():
                self.appendQuoted(prefix, (value as! Int64).toString(), to: builder)
            case Type<Int128>():
                self.appendQuoted(prefix, (value as! Int128).toString(), to: builder)
            case Type<Int256>():
                self.appendQuoted(prefix, (value as! Int256).toString(), to: builder)
            case Type<Int>():
                self.appendQuoted(prefix, (value as! Int).toString(), to: builder)
            case Type<UInt8>():
                self.appendQuoted(prefix, (value as! UInt8).toString(), to: builder)
            case Type<UInt16>():
                self.appendQuoted(prefix, (value as! UInt16).toString(), to: builder)
            case Type<UInt32>():
                self.appendQuoted(prefix, (value as! UInt32).toString(), to: builder)
            case Type<UInt64>():
                self.appendQuoted(prefix, (value as! UInt64).toString(), to: builder)
            case Type<UInt128>():
                self.appendQuoted(prefix, (value as! UInt128).toString(), to: builder)
            case Type<UInt256>():
                self.appendQuoted(prefix, (value as! UInt256).toString(), to: builder)
            case Type<UInt>():
                self.appendQuoted(prefix, (value as! UInt).toString(), to: builder)
            case Type<Word8>():
                self.appendQuoted(prefix, (value as! Word8).toString(), to: builder)
            case Type<Word16>():
                self.appendQuoted(prefix, (value as! Word16).toString(), to: builder)
            case Type<Word32>():
                self.appendQuoted(prefix, (value as! Word32).toString(), to: builder)
            case Type<Word64>():
                self.appendQuoted(prefix, (value as! Word64).toString(), to: builder)
            case Type<Word128>():
                self.appendQuoted(prefix, (value as! Word128).toString(), to: builder)
            case Type<Word256>():
                self.appendQuoted(prefix, (value as! Word256).toString(), to: builder)
            case Type<UFix64>():
                self.appendQuoted(prefix, (value as! UFix64).toString(), to: builder)
            default:
                return false
        }
        return true
    }

    /// Appends `prefix` followed by `inner` wrapped in double quotes to `builder`.
    ///
    access(self)
    fun appendQuoted(_ prefix: String, _ inner: String, to builder: StringBuilder) {
        builder.append(prefix)
        builder.append("\"")
        builder.append(inner)
        builder.append("\"")
    }

    /// Appends `prefix` followed by the JSON-escaped form of `str` wrapped in double quotes to `builder`.
    ///
    access(self)
    fun appendQuotedEscaped(_ prefix: String, _ str: String, to builder: StringBuilder) {
        builder.append(prefix)
        builder.append("\"")
        self.appendEscapedJSONString(str, to: builder)
        builder.append("\"")
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
        let builder = StringBuilder()
        self.appendEscapedJSONString(str, to: builder)
        return builder.toString()
    }

    /// Appends `str` to `builder`, escaped for inclusion in a JSON string literal (without surrounding quotes).
    /// Backslash, double quote, and control characters U+0000 through U+001F are escaped per
    /// RFC 8259 Section 7. Additionally, the HTML-significant characters `<`, `>`, `&` and the
    /// U+2028 / U+2029 line/paragraph separators are escaped defensively: the metadata is often
    /// rendered in browsers, where `<`, `>`, `&` enable XSS and U+2028 / U+2029 are invalid in
    /// JavaScript string literals. All escapes are valid JSON, so parsers recover the original text.
    /// All other characters, including multi-byte UTF-8 sequences, pass through unchanged.
    ///
    access(self)
    fun appendEscapedJSONString(_ str: String, to builder: StringBuilder) {
        let bytes = str.utf8
        // Fast path: append unchanged if nothing needs escaping (the common case)
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
            builder.append(str)
            return
        }

        let hexDigits = "0123456789abcdef"
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
    }

    /// Returns a serialized representation of the given array. Non-serializable elements are skipped.
    ///
    access(all)
    fun arrayToJSONString(_ arr: [AnyStruct]): String? {
        let builder = StringBuilder()
        self.appendArrayJSONString(arr, to: builder)
        return builder.toString()
    }

    /// Appends a serialized representation of the given array to `builder`. Non-serializable elements are skipped.
    ///
    access(self)
    fun appendArrayJSONString(_ arr: [AnyStruct], to builder: StringBuilder) {
        builder.append("[")
        var first = true
        for element in arr {
            // The leading ", " separator is committed only if the element is serializable
            if self.appendJSONString(element, to: builder, prefix: first ? "" : ", ") {
                first = false
            }
        }
        builder.append("]")
    }

    /// Returns a serialized representation of the given String-indexed mapping or nil if the value is not serializable.
    /// The interface here is largely the same as as the `MetadataViews.dictToTraits` method, though here
    /// a JSON-compatible String is returned instead of a `Traits` array.
    ///
    access(all)
    fun dictToJSONString(dict: {String: AnyStruct}, excludedNames: [String]?): String? {
        let builder = StringBuilder()
        self.appendDictJSONString(dict: dict, excludedNames: excludedNames, to: builder)
        return builder.toString()
    }

    /// Appends a serialized representation of the given String-indexed mapping to `builder`.
    /// The interface here is largely the same as as the `MetadataViews.dictToTraits` method, though here
    /// a JSON-compatible String is appended instead of a `Traits` array. Entries whose value is not
    /// serializable, as well as any keys in `excludedNames`, are skipped.
    ///
    access(self)
    fun appendDictJSONString(dict: {String: AnyStruct}, excludedNames: [String]?, to builder: StringBuilder) {
        if let excludedNames = excludedNames {
            for k in excludedNames {
                dict.remove(key: k)
            }
        }
        builder.append("{")
        var first = true
        for key in dict {
            // The separator, escaped key, and ": " are committed only if the value is serializable
            let prefix = "\(first ? "" : ", ")\"\(self.escapeJSONString(key))\": "
            if self.appendJSONString(dict[key]!, to: builder, prefix: prefix) {
                first = false
            }
        }
        builder.append("}")
    }
}
