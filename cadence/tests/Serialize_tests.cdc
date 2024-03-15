import Test
import BlockchainHelpers

import "Serialize"

access(all)
let serializeAccount = Test.getAccount(0x0000000000000007)

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
fun testBoolToStringSucceeds() {
    let t: Bool = true
    let f: Bool = false

    let expectedTrue = "true"
    let expectedFalse = "false"
    
    var actualTrue = Serialize.boolToString(t)
    var actualFalse = Serialize.boolToString(f)
    
    Test.assertEqual(expectedTrue, actualTrue)
    Test.assertEqual(expectedFalse, actualFalse)
}

// access(all)
// fun testArrayToStringSucceeds() {
//     let arr: [AnyStruct] = 

//     let expected = "\"true\""
    
//     var actual = Serialize.tryToJSONString(t)
    
//     Test.assertEqual(expectedTrue, actualTrue!)
//     Test.assertEqual(expectedFalse, actualFalse!)
// }