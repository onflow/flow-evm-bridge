import Test
import BlockchainHelpers

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let alice = Test.createAccount()

access(all) fun setup() {
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
        name: "SerializeNFT",
        path: "../contracts/utils/SerializeNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Update the EVM contract with our updates
    // TODO: Remove once included in the standard EVM contract
    let evmUpdateResult = executeTransaction(
        "../transactions/test/update_contract.cdc",
        ["EVM", getUpdatedEVMCode().decodeHex()],
        serviceAccount
    )
    Test.expect(evmUpdateResult, Test.beSucceeded())
}

access(all)
fun testCreateCOASucceeds() {
    let transferFlowResult = executeTransaction(
        "../transactions/flow-token/transfer_flow.cdc",
        [alice.address, 1000.0],
        serviceAccount
    )
    Test.expect(transferFlowResult, Test.beSucceeded())

    let createCOAResult = executeTransaction(
        "../transactions/evm/create_account.cdc",
        [1000.0],
        alice
    )
    Test.expect(createCOAResult, Test.beSucceeded())

    let coaAddressResult = executeScript(
        "../scripts/evm/get_evm_address_string.cdc",
        [alice.address]
    )
    Test.expect(coaAddressResult, Test.beSucceeded())
    let stringAddress = coaAddressResult.returnValue as! String?
    Test.assertEqual(40, stringAddress!.length)
}
