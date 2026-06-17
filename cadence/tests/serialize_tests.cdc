import Test
import BlockchainHelpers

import "Serialize"

access(all) let admin = Test.getAccount(0x0000000000000007)
access(all) let alice = Test.createAccount()

access(all) struct NonSerializable {
    access(all) let foo: String
    init() {
        self.foo = "foo"
    }
}

access(all)
fun setup() {
    var err = Test.deployContract(
        name: "Serialize",
        path: "../contracts/utils/Serialize.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun testIntsTryToJSONStringSucceeds() {
    let i: Int = 127
    let i8: Int8 = 127
    let i16: Int16 = 127
    let i32: Int32 = 127
    let i64: Int64 = 127
    let i128: Int128 = 127
    let i256: Int256 = 127

    let expected = "\"127\""

    var actual = Serialize.tryToJSONString(i)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(i8)
    Test.assertEqual(expected, actual!)

    actual = Serialize.tryToJSONString(i16)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(i32)
    Test.assertEqual(expected, actual!)

    actual = Serialize.tryToJSONString(i64)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(i128)
    Test.assertEqual(expected, actual!)

    actual = Serialize.tryToJSONString(i256)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testUIntsTryToJSONStringSucceeds() {
    let ui: UInt = 255
    let ui8: UInt8 = 255
    let ui16: UInt16 = 255
    let ui32: UInt32 = 255
    let ui64: UInt64 = 255
    let ui128: UInt128 = 255
    let ui256: UInt256 = 255

    let expected = "\"255\""
    
    var actual = Serialize.tryToJSONString(ui)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(ui8)
    Test.assertEqual(expected, actual!)

    actual = Serialize.tryToJSONString(ui16)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(ui32)
    Test.assertEqual(expected, actual!)

    actual = Serialize.tryToJSONString(ui64)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(ui128)
    Test.assertEqual(expected, actual!)

    actual = Serialize.tryToJSONString(ui256)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testWordsTryToJSONStringSucceeds() {
    let word8: Word8 = 255
    let word16: Word16 = 255
    let word32: Word32 = 255
    let word64: Word64 = 255
    let word128: Word128 = 255
    let word256: Word256 = 255

    let expected = "\"255\""
    
    var actual = Serialize.tryToJSONString(word8)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(word16)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(word32)
    Test.assertEqual(expected, actual!)

    actual = Serialize.tryToJSONString(word64)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(word128)
    Test.assertEqual(expected, actual!)

    actual = Serialize.tryToJSONString(word256)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testAddressTryToJSONStringSucceeds() {
    let address: Address = 0x0000000000000007
    let addressOpt: Address? = nil

    let expected = "\"0x0000000000000007\""
    let expectedOpt = "\"nil\""
    
    var actual = Serialize.tryToJSONString(address)
    Test.assertEqual(expected, actual!)
    
    var actualOpt = Serialize.tryToJSONString(addressOpt)
    Test.assertEqual(expectedOpt, actualOpt!)
}

access(all)
fun testStringTryToJSONStringSucceeds() {
    let str: String = "Hello, World!"
    let strOpt: String? = nil

    let expected = "\"Hello, World!\""
    let expectedOpt = "\"nil\""
    
    var actual = Serialize.tryToJSONString(str)
    Test.assertEqual(expected, actual!)
    
    var actualOpt = Serialize.tryToJSONString(strOpt)
    Test.assertEqual(expectedOpt, actualOpt!)
}

access(all)
fun testCharacterTryToJSONStringSucceeds() {
    let char: Character = "c"
    let charOpt: Character? = nil

    let expected = "\"c\""
    let expectedOpt = "\"nil\""
    
    var actual = Serialize.tryToJSONString(char)
    Test.assertEqual(expected, actual!)
    
    var actualOpt = Serialize.tryToJSONString(charOpt)
    Test.assertEqual(expectedOpt, actualOpt!)
}

access(all)
fun testStringWithQuotesTryToJSONStringSucceeds() {
    // input chars: say "hello" -> output chars: "say \"hello\""
    let str = "say \"hello\""

    let expected = "\"say \\\"hello\\\"\""

    var actual = Serialize.tryToJSONString(str)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testStringWithBackslashTryToJSONStringSucceeds() {
    // input chars: back\slash -> output chars: "back\\slash"
    let str = "back\\slash"

    let expected = "\"back\\\\slash\""

    var actual = Serialize.tryToJSONString(str)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testStringWithWhitespaceControlsTryToJSONStringSucceeds() {
    // newline, carriage return & tab -> \n \r \t escape sequences
    let str = "line1\nline2\rline3\tend"

    let expected = "\"line1\\nline2\\rline3\\tend\""

    var actual = Serialize.tryToJSONString(str)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testStringWithBackspaceAndFormFeedTryToJSONStringSucceeds() {
    // backspace (U+0008) & form feed (U+000C) -> \b \f escape sequences
    let str = "a\u{8}b\u{c}c"

    let expected = "\"a\\bb\\fc\""

    var actual = Serialize.tryToJSONString(str)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testStringWithControlCharsTryToJSONStringSucceeds() {
    // U+0001 & U+001F have no shorthand escapes -> \u00XX with lowercase hex
    let str = "a\u{1}b\u{1f}c"

    let expected = "\"a\\u0001b\\u001fc\""

    var actual = Serialize.tryToJSONString(str)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testStringWithUnicodeTryToJSONStringSucceeds() {
    // multi-byte UTF-8 characters must pass through unmodified: é (U+00E9), ☕ (U+2615), 😀 (U+1F600)
    let str = "Caf\u{e9} \u{2615} \u{1f600}"

    let expected = "\"Caf\u{e9} \u{2615} \u{1f600}\""

    var actual = Serialize.tryToJSONString(str)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testStringWithHTMLCharsTryToJSONStringSucceeds() {
    // <, >, & are escaped defensively to prevent XSS when the metadata is rendered in a browser
    let str = "<script>alert('x')</script> a&b"

    let expected = "\"\\u003cscript\\u003ealert('x')\\u003c/script\\u003e a\\u0026b\""

    var actual = Serialize.tryToJSONString(str)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testStringWithLineParagraphSeparatorsTryToJSONStringSucceeds() {
    // U+2028 LINE SEPARATOR & U+2029 PARAGRAPH SEPARATOR are valid JSON but invalid in JS string
    // literals, so they are escaped to \u2028 / \u2029
    let str = "a\u{2028}b\u{2029}c"

    let expected = "\"a\\u2028b\\u2029c\""

    var actual = Serialize.tryToJSONString(str)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testOptionalStringWithSpecialCharsTryToJSONStringSucceeds() {
    let strOpt: String? = "opt\n\"quoted\""

    let expected = "\"opt\\n\\\"quoted\\\"\""

    var actual = Serialize.tryToJSONString(strOpt)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testCharacterWithSpecialCharTryToJSONStringSucceeds() {
    let newline: Character = "\n"
    let quote: Character = "\""

    var actual = Serialize.tryToJSONString(newline)
    Test.assertEqual("\"\\n\"", actual!)

    actual = Serialize.tryToJSONString(quote)
    Test.assertEqual("\"\\\"\"", actual!)
}

access(all)
fun testDictWithSpecialCharKeyToJSONStringSucceeds() {
    // single-entry dict avoids key-ordering nondeterminism
    let dict: {String: AnyStruct} = {"key\nwith \"specials\"": "value\twith tab"}

    let expected = "{\"key\\nwith \\\"specials\\\"\": \"value\\twith tab\"}"

    var actual = Serialize.dictToJSONString(dict: dict, excludedNames: nil)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testEscapeJSONStringWithoutSpecialCharsReturnsUnchanged() {
    Test.assertEqual("Hello, World!", Serialize.escapeJSONString("Hello, World!"))
    Test.assertEqual("", Serialize.escapeJSONString(""))
}

access(all)
fun testUFix64TryToJSONStringSucceeds() {
    let uf64: UFix64 = UFix64.max

    let expected = "\"184467440737.09551615\""
    
    var actual = Serialize.tryToJSONString(uf64)
    Test.assertEqual(expected, actual!)
}

access(all)
fun testBoolTryToJSONStringSucceeds() {
    let t: Bool = true
    let f: Bool = false

    let expectedTrue = "\"true\""
    let expectedFalse = "\"false\""
    
    var actualTrue = Serialize.tryToJSONString(t)
    var actualFalse = Serialize.tryToJSONString(f)
    
    Test.assertEqual(expectedTrue, actualTrue!)
    Test.assertEqual(expectedFalse, actualFalse!)
}

access(all)
fun testArrayToJSONStringSucceeds() {
    let arr: [AnyStruct] = [
            NonSerializable(),
            127,
            255,
            "Hello, World!",
            "c",
            Address(0x0000000000000007),
            NonSerializable(),
            UFix64.max,
            true,
            NonSerializable(),
            NonSerializable()
        ]

    let expected = "[\"127\", \"255\", \"Hello, World!\", \"c\", \"0x0000000000000007\", \"184467440737.09551615\", \"true\"]"
    
    var actual = Serialize.arrayToJSONString(arr)

    Test.assertEqual(expected, actual!)
}

access(all)
fun testEmptyArrayToJSONStringSucceeds() {
    let arr: [AnyStruct] = []

    let expected = "[]"
    
    var actual = Serialize.arrayToJSONString(arr)

    Test.assertEqual(expected, actual!)
}

access(all)
fun testDictToJSONStringSucceeds() {
    let dict: {String: AnyStruct} = {
            "bar": NonSerializable(),
            "bool": true,
            "arr": [ 127, "Hello, World!" ],
            "foo": NonSerializable()
        }

    // Mapping values can be indexed in arbitrary order, so we need to check for all possible outputs
    var expectedOne: String = "{\"bool\": \"true\", \"arr\": [\"127\", \"Hello, World!\"]}"
    var expectedTwo: String = "{\"arr\": [\"127\", \"Hello, World!\"], \"bool\": \"true\"}"
    
    var actual: String? = Serialize.dictToJSONString(dict: dict, excludedNames: nil)
    Test.assertEqual(true, expectedOne == actual! || expectedTwo == actual!)
    
    actual = Serialize.tryToJSONString(dict)
    Test.assertEqual(true, expectedOne == actual! || expectedTwo == actual!)

    actual = Serialize.dictToJSONString(dict: dict, excludedNames: ["bool"])
    expectedOne = "{\"arr\": [\"127\", \"Hello, World!\"]}"
    Test.assertEqual(true, expectedOne == actual!)
}

access(all)
fun testEmptyDictToJSONStringSucceeds() {
    let dict: {String: AnyStruct} = {}

    // Mapping values can be indexed in arbitrary order, so we need to check for all possible outputs
    var expected: String = "{}"
    
    var actual: String? = Serialize.dictToJSONString(dict: dict, excludedNames: nil)
    Test.assertEqual(expected, actual!)
    
    actual = Serialize.tryToJSONString(dict)
    Test.assertEqual(expected, actual!)
}
