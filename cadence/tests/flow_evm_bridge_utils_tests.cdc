import Test
import BlockchainHelpers

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)

access(all)
fun setup() {
    // Deploy supporting util contracts
    var err = Test.deployContract(
        name: "ArrayUtils",
        path: "../contracts/utils/ArrayUtils.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "StringUtils",
        path: "../contracts/utils/StringUtils.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "ScopedFTProviders",
        path: "../contracts/utils/ScopedFTProviders.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "Serialize",
        path: "../contracts/utils/Serialize.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "SerializeMetadata",
        path: "../contracts/utils/SerializeMetadata.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "EVMUtils",
        path: "../contracts/utils/EVMUtils.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Update MetadataViews contract with proposed URI & EVMBridgedMetadata view COA integration
    // TODO: Remove once MetadataViews contract is updated in CLI's core contracts
    var updateResult = executeTransaction(
        "./transactions/update_contract.cdc",
        ["MetadataViews", getMetadataViewsUpdateCode()],
        serviceAccount
    )
    // Update EVM contract with proposed bridge-supporting COA integration
    // TODO: Remove once EVM contract is updated in CLI's core contracts
    updateResult = executeTransaction(
        "./transactions/update_contract.cdc",
        ["EVM", getEVMUpdateCode()],
        serviceAccount
    )
    Test.expect(updateResult, Test.beSucceeded())
    // Transfer bridge account some $FLOW
    transferFlow(signer: serviceAccount, recipient: bridgeAccount.address, amount: 10_000.0)
    // Configure bridge account with a COA
    createCOA(signer: bridgeAccount, fundingAmount: 1_000.0)

    err = Test.deployContract(
        name: "IBridgePermissions",
        path: "../contracts/bridge/interfaces/IBridgePermissions.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "ICrossVM",
        path: "../contracts/bridge/interfaces/ICrossVM.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "CrossVMNFT",
        path: "../contracts/bridge/interfaces/CrossVMNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "CrossVMToken",
        path: "../contracts/bridge/interfaces/CrossVMToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeHandlerInterfaces",
        path: "../contracts/bridge/interfaces/FlowEVMBridgeHandlerInterfaces.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeConfig",
        path: "../contracts/bridge/FlowEVMBridgeConfig.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeUtils",
        path: "../contracts/bridge/FlowEVMBridgeUtils.cdc",
        arguments: [getCompiledFactoryBytecode()]
    )
}

access(all)
fun testReducedPrecisionUInt256ToUFix64Succeeds() {
    let uintAmount: UInt256 = 24_244_814_054_591
    let ufixAmount: UFix64 = 24_244_814.05459100

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

    log("testLargeFractionalUInt256ToUFix64Succeeds")

    let actualUFixAmount = uint256ToUFix64(largeFractionalUIntAmount, decimals: 18)
    Test.assertEqual(largeFractionalUFixAmount, actualUFixAmount)
}

access(all)
fun testlargeFractionalUFix64ToUInt256Succeeds() {
    let largeFractionalUFixAmount: UFix64 = 1.99785982
    let largeFractionalUIntAmount: UInt256 = 1_997_859_820_000_000_000
    // let largeFractionalUIntAmount: UInt256 = 1,997,859,820,000,000,000

    log("testlargeFractionalUFix64ToUInt256Succeeds")

    let actualUIntAmount = ufix64ToUInt256(largeFractionalUFixAmount, decimals: 18)
    Test.assertEqual(largeFractionalUIntAmount, actualUIntAmount)
}
