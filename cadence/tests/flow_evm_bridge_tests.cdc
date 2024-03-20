import Test
import BlockchainHelpers

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let exampleERC721Account = Test.createAccount()
access(all) let alice = Test.createAccount()

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
        name: "SerializeNFT",
        path: "../contracts/utils/SerializeNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    
    // Update EVM contract with proposed bridge-supporting COA integration
    let updateResult = executeTransaction(
        "../transactions/test/update_contract.cdc",
        ["EVM", getEVMUpdateCode()],
        serviceAccount
    )
    Test.expect(updateResult, Test.beSucceeded())
    // Transfer bridge account some $FLOW
    let transferFlowResult = executeTransaction(
        "../transactions/flow-token/transfer_flow.cdc",
        [bridgeAccount.address, 10_000.0],
        serviceAccount
    )
    Test.expect(transferFlowResult, Test.beSucceeded())
    // Configure bridge account with a COA
    let createCOAResult = executeTransaction(
        "../transactions/evm/create_account.cdc",
        [1_000.0],
        bridgeAccount
    )
    Test.expect(createCOAResult, Test.beSucceeded())

    err = Test.deployContract(
        name: "BridgePermissions",
        path: "../contracts/bridge/BridgePermissions.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "ICrossVM",
        path: "../contracts/bridge/ICrossVM.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "CrossVMNFT",
        path: "../contracts/bridge/CrossVMNFT.cdc",
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
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeNFTEscrow",
        path: "../contracts/bridge/FlowEVMBridgeNFTEscrow.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeTemplates",
        path: "../contracts/bridge/FlowEVMBridgeTemplates.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    // Commit bridged NFT code
    let bridgedNFTChunkResult = executeTransaction(
        "../transactions/bridge/admin/upsert_contract_code_chunks.cdc",
        ["bridgedNFT", getBridgedNFTCodeChunks()],
        bridgeAccount
    )
    Test.expect(bridgedNFTChunkResult, Test.beSucceeded())

    err = Test.deployContract(
        name: "IEVMBridgeNFTMinter",
        path: "../contracts/bridge/IEVMBridgeNFTMinter.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "IFlowEVMNFTBridge",
        path: "../contracts/bridge/IFlowEVMNFTBridge.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridge",
        path: "../contracts/bridge/FlowEVMBridge.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "EVMBridgeRouter",
        path: "../contracts/bridge/EVMBridgeRouter.cdc",
        arguments: [serviceAccount.address, "FlowEVMBridge"]
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun testCreateCOASucceeds() {
    let transferFlowResult = executeTransaction(
        "../transactions/flow-token/transfer_flow.cdc",
        [alice.address, 1_000.0],
        serviceAccount
    )
    Test.expect(transferFlowResult, Test.beSucceeded())

    let createCOAResult = executeTransaction(
        "../transactions/evm/create_account.cdc",
        [100.0],
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
