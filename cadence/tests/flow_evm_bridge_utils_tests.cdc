import Test
import BlockchainHelpers

import "CrossVMMetadataViews"
import "EVM"
import "FlowEVMBridgeUtils"
import "FlowEVMBridgeConfig"
import "ExampleCadenceNativeNFT"
import "ExampleEVMNativeNFT"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)

access(all) var cadenceNativeERC721AddressHex: String = ""
access(all) var evmNativeERC721AddressHex: String = ""

access(all)
fun setup() {
    setupBridge(bridgeAccount: bridgeAccount, serviceAccount: serviceAccount, unpause: true)

    var err = Test.deployContract(
        name: "ExampleCadenceNativeNFT",
        path: "../contracts/example-assets/cross-vm-nfts/ExampleCadenceNativeNFT.cdc",
        arguments: [getCadenceNativeERC721Bytecode(), "Example Cadence-Native NFT", "XMPL"]
    )
    Test.expect(err, Test.beNil())
    cadenceNativeERC721AddressHex = ExampleCadenceNativeNFT.getEVMContractAddress().toString()

    err = Test.deployContract(
        name: "ExampleEVMNativeNFT",
        path: "../contracts/example-assets/cross-vm-nfts/ExampleEVMNativeNFT.cdc",
        arguments: [getEVMNativeERC721Bytecode()]
    )
    Test.expect(err, Test.beNil())
    evmNativeERC721AddressHex = ExampleEVMNativeNFT.getEVMContractAddress().toString()
}

access(all)
fun testReducedPrecisionUInt256ToUFix64Succeeds() {
    let uintAmount: UInt256 = 24_244_814_054_591
    let ufixAmount: UFix64 = 24_244_814.05459100

    let actualUFixAmount = uint256ToUFix64(uintAmount, decimals: 6)
    Test.assertEqual(ufixAmount, actualUFixAmount)
}

access(all)
fun testReducedPrecisionUInt256SmallChangeToUFix64Succeeds() {
    let uintAmount: UInt256 = 24_244_814_000_020
    let ufixAmount: UFix64 = 24_244_814.000020

    let actualUFixAmount = uint256ToUFix64(uintAmount, decimals: 6)
    Test.assertEqual(ufixAmount, actualUFixAmount)
}

// Converting from UFix64 to UInt256 with reduced point precision (6 vs. 8) should round down
access(all)
fun testReducedPrecisionUFix64ToUInt256Succeeds() {
    let uintAmount: UInt256 = 24_244_814_054_591
    let ufixAmount: UFix64 = 24_244_814.05459154

    let actualUIntAmount = ufix64ToUInt256(ufixAmount, decimals: 6)
    Test.assertEqual(uintAmount, actualUIntAmount)
}

access(all)
fun testDustUInt256ToUFix64Succeeds() {
    let dustUFixAmount: UFix64 = 0.00002547
    let dustUIntAmount: UInt256 = 25_470_000_000_000

    let actualUFixAmount = uint256ToUFix64(dustUIntAmount, decimals: 18)
    Test.assertEqual(dustUFixAmount, actualUFixAmount)
    Test.assert(actualUFixAmount > 0.0)
}

access(all)
fun testDustUFix64ToUInt256Succeeds() {
    let dustUFixAmount: UFix64 = 0.00002547
    let dustUIntAmount: UInt256 = 25_470_000_000_000

    let actualUIntAmount = ufix64ToUInt256(dustUFixAmount, decimals: 18)
    Test.assertEqual(dustUIntAmount, actualUIntAmount)
    Test.assert(actualUIntAmount > 0)
}

access(all)
fun testZeroUInt256ToUFix64Succeeds() {
    let zeroUFixAmount: UFix64 = 0.0
    let zeroUIntAmount: UInt256 = 0

    let actualUFixAmount = uint256ToUFix64(zeroUIntAmount, decimals: 18)
    Test.assertEqual(zeroUFixAmount, actualUFixAmount)
}

access(all)
fun testZeroUFix64ToUInt256Succeeds() {
    let zeroUFixAmount: UFix64 = 0.0
    let zeroUIntAmount: UInt256 = 0

    let actualUIntAmount = ufix64ToUInt256(zeroUFixAmount, decimals: 18)
    Test.assertEqual(zeroUIntAmount, actualUIntAmount)
}

access(all)
fun testNonFractionalUInt256ToUFix64Succeeds() {
    let nonFractionalUFixAmount: UFix64 = 100.0
    let nonFractionalUIntAmount: UInt256 = 100_000_000_000_000_000_000

    let actualUFixAmount = uint256ToUFix64(nonFractionalUIntAmount, decimals: 18)
    Test.assertEqual(nonFractionalUFixAmount, actualUFixAmount)
}

access(all)
fun testNonFractionalUFix64ToUInt256Succeeds() {
    let nonFractionalUFixAmount: UFix64 = 100.0
    let nonFractionalUIntAmount: UInt256 = 100_000_000_000_000_000_000

    let actualUIntAmount = ufix64ToUInt256(nonFractionalUFixAmount, decimals: 18)
    Test.assertEqual(nonFractionalUIntAmount, actualUIntAmount)
}

access(all)
fun testLargeFractionalUInt256ToUFix64Succeeds() {
    let largeFractionalUFixAmount: UFix64 = 1.99785982
    let largeFractionalUIntAmount: UInt256 = 1_997_859_829_999_999_999

    let actualUFixAmount = uint256ToUFix64(largeFractionalUIntAmount, decimals: 18)
    Test.assertEqual(largeFractionalUFixAmount, actualUFixAmount)
}

access(all)
fun testLargeFractionalTrailingZerosUInt256ToUFix64Succeeds() {
    let largeFractionalUFixAmount: UFix64 = 1.99785982
    let largeFractionalUIntAmount: UInt256 = 1_997_859_829_999_000_000

    let actualUFixAmount = uint256ToUFix64(largeFractionalUIntAmount, decimals: 18)
    Test.assertEqual(largeFractionalUFixAmount, actualUFixAmount)
}

access(all)
fun testlargeFractionalUFix64ToUInt256Succeeds() {
    let largeFractionalUFixAmount: UFix64 = 1.99785982
    let largeFractionalUIntAmount: UInt256 = 1_997_859_820_000_000_000

    let actualUIntAmount = ufix64ToUInt256(largeFractionalUFixAmount, decimals: 18)
    Test.assertEqual(largeFractionalUIntAmount, actualUIntAmount)
}

access(all)
fun testIntegerAndLeadingZeroFractionalUInt256ToUFix64Succeeds() {
    let ufixAmount: UFix64 = 100.00000500
    let uintAmount: UInt256 = 100_000_005_000_000_888_999

    let actualUFixAmount = uint256ToUFix64(uintAmount, decimals: 18)
    Test.assertEqual(ufixAmount, actualUFixAmount)
}

access(all)
fun testIntegerAndLeadingZeroFractionalUFix64ToUInt256Succeeds() {
    let ufixAmount: UFix64 = 100.00000500
    let uintAmount: UInt256 = 100_000_005_000_000_000_000

    let actualUIntAmount = ufix64ToUInt256(ufixAmount, decimals: 18)
    Test.assertEqual(uintAmount, actualUIntAmount)
}

access(all)
fun testMaxUFix64ToUInt256Succeeds() {
    let ufixAmount: UFix64 = UFix64.max
    let uintAmount: UInt256 = 184467440737_095516150000000000

    let actualUIntAmount = ufix64ToUInt256(ufixAmount, decimals: 18)

    Test.assertEqual(uintAmount, actualUIntAmount)
}

access(all)
fun testMaxUFix64AsUInt256ToUFix64Succeds() {
    let ufixAmount: UFix64 = UFix64.max
    var uintAmount: UInt256 = 184467440737_095516150000000000

    let actualUFixAmount = uint256ToUFix64(uintAmount, decimals: 18)

    Test.assertEqual(ufixAmount, actualUFixAmount)
}

access(all)
fun testFractionalPartMaxUFix64AsUInt256ToUFix64Fails() {
    let ufixAmount: UFix64 = UFix64.max
    var uintAmount: UInt256 = 184467440737_095_516_150_000_000_000 + 10_000_000_000

    let convertedResult = executeScript(
        "../scripts/utils/uint256_to_ufix64.cdc",
        [uintAmount, UInt8(18)]
    )
    Test.expect(convertedResult, Test.beFailed())
}

access(all)
fun testIntegerPartMaxUFix64AsUInt256ToUFix64Fails() {
    let ufixAmount: UFix64 = UFix64.max
    var uintAmount: UInt256 = 184467440737_095_516_150_000_000_000 + 100_000_000_000_000_000_000_000

    let convertedResult = executeScript(
        "../scripts/utils/uint256_to_ufix64.cdc",
        [uintAmount, UInt8(18)]
    )
    Test.expect(convertedResult, Test.beFailed())
}

access(all)
fun testGetEVMPointerViewSucceeds() {
    let type = Type<@ExampleCadenceNativeNFT.NFT>()
    let res = executeScript(
        "../scripts/nft/get_evm_pointer_from_identifier.cdc",
        [type.identifier]
    )
    Test.expect(res, Test.beSucceeded())
    let view = res.returnValue as! CrossVMMetadataViews.EVMPointer?
        ?? panic("Could not get EVMPointerView for \(type.identifier) via FlowEVMBridgeUtils")

    Test.assertEqual(type, view.cadenceType)
    Test.assertEqual(type.address!, view.cadenceContractAddress)
    Test.assertEqual(cadenceNativeERC721AddressHex, view.evmContractAddress.toString().toLower())
}

access(all)
fun testGetDeclaredCadenceAddressFromCrossVM() {
    // Negative case
    var res = executeScript(
        "../scripts/utils/get_declared_cadence_address.cdc",
        [FlowEVMBridgeUtils.getBridgeFactoryEVMAddress().toString()] // not an ICrossVM.sol conforming contract - should return nil
    )
    Test.expect(res, Test.beSucceeded())
    
    var declaredAddr = res.returnValue as! Address?
    Test.assertEqual(nil, declaredAddr)

    // Positive case
    res = executeScript(
        "../scripts/utils/get_declared_cadence_address.cdc",
        [ExampleCadenceNativeNFT.getEVMContractAddress().toString()]
    )
    Test.expect(res, Test.beSucceeded())

    declaredAddr = res.returnValue as! Address? ?? panic("Could not get declared Cadence address from cross-VM EVM contract")
    Test.assertEqual(Type<@ExampleCadenceNativeNFT.NFT>().address, declaredAddr)
}

access(all)
fun testGetDeclaredCadenceTypeFromCrossVM() {
    // Negative case
    var res = executeScript(
        "../scripts/utils/get_declared_cadence_type.cdc",
        [FlowEVMBridgeUtils.getBridgeFactoryEVMAddress().toString()] // not an ICrossVM.sol conforming contract - should return nil
    )
    Test.expect(res, Test.beSucceeded())
    
    var declaredType = res.returnValue as! Type?
    Test.assertEqual(nil, declaredType)

    // Positive case
    res = executeScript(
        "../scripts/utils/get_declared_cadence_type.cdc",
        [ExampleCadenceNativeNFT.getEVMContractAddress().toString()]
    )
    Test.expect(res, Test.beSucceeded())

    declaredType = res.returnValue as! Type? ?? panic("Could not get declared Cadence address from cross-VM EVM contract")
    Test.assertEqual(Type<@ExampleCadenceNativeNFT.NFT>(), declaredType!)
}

access(all)
fun testSupportsICrossVMBridgeERC721Fulfillment() {
    // Negative case
    var res = executeScript(
        "../scripts/utils/supports_icross_vm_bridge_erc721_fulfillment.cdc",
        [ExampleEVMNativeNFT.getEVMContractAddress().toString()] // not a conforming contract - should return false
    )
    Test.expect(res, Test.beSucceeded())
    
    var supports = res.returnValue as! Bool
    Test.assertEqual(false, supports)

    // Positive case
    res = executeScript(
        "../scripts/utils/supports_icross_vm_bridge_erc721_fulfillment.cdc",
        [ExampleCadenceNativeNFT.getEVMContractAddress().toString()]
    )
    Test.expect(res, Test.beSucceeded())

    supports = res.returnValue as! Bool
    Test.assertEqual(true, supports)
}

access(all)
fun testSupportsICrossVMBridgeCallable() {
    // Negative case
    var res = executeScript(
        "../scripts/utils/supports_icross_vm_bridge_callable.cdc",
        [ExampleEVMNativeNFT.getEVMContractAddress().toString()] // not a conforming contract - should return false
    )
    Test.expect(res, Test.beSucceeded())
    
    var supports = res.returnValue as! Bool
    Test.assertEqual(false, supports)

    // Positive case
    res = executeScript(
        "../scripts/utils/supports_icross_vm_bridge_callable.cdc",
        [ExampleCadenceNativeNFT.getEVMContractAddress().toString()]
    )
    Test.expect(res, Test.beSucceeded())

    supports = res.returnValue as! Bool
    Test.assertEqual(true, supports)
}

access(all)
fun testSupportsCadenceNativeNFTEVMInterfaces() {
    // Negative case
    var res = executeScript(
        "../scripts/utils/supports_cadence_native_nft_evm_interfaces.cdc",
        [ExampleEVMNativeNFT.getEVMContractAddress().toString()] // not a conforming contract - should return false
    )
    Test.expect(res, Test.beSucceeded())
    
    var supports = res.returnValue as! Bool
    Test.assertEqual(false, supports)

    // Positive case
    res = executeScript(
        "../scripts/utils/supports_cadence_native_nft_evm_interfaces.cdc",
        [ExampleCadenceNativeNFT.getEVMContractAddress().toString()]
    )
    Test.expect(res, Test.beSucceeded())

    supports = res.returnValue as! Bool
    Test.assertEqual(true, supports)
}

access(all)
fun testGetVMBridgeAddressFromICrossVMBridgeCallable() {
    // Negative case
    var res = executeScript(
        "../scripts/utils/get_vm_bridge_address_from_icross_vm.cdc",
        [ExampleEVMNativeNFT.getEVMContractAddress().toString()] // not a conforming contract - should return false
    )
    Test.expect(res, Test.beSucceeded())
    
    var address = res.returnValue as! EVM.EVMAddress?
    Test.assertEqual(nil, address)

    // Positive case
    res = executeScript(
        "../scripts/utils/get_vm_bridge_address_from_icross_vm.cdc",
        [ExampleCadenceNativeNFT.getEVMContractAddress().toString()]
    )
    Test.expect(res, Test.beSucceeded())

    address = res.returnValue as! EVM.EVMAddress? ?? panic("Could not get declared VM bridge address from ICrossVMBridgeCallable")
    Test.assertEqual(getBridgeCOAAddressHex(), address!.toString().toLower())
}

