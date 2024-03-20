import Test
import BlockchainHelpers

access(all) let serviceAccount = Test.serviceAccount()
access(all) let alice = Test.createAccount()

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
