import Test
import BlockchainHelpers

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let exampleERC721Account = Test.getAccount(0x0000000000000009)
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

    let fundBridgeResult = executeTransaction(
        "../transactions/flow-token/transfer_flow.cdc",
        [bridgeAccount.address, 1000.0],
        serviceAccount
    )
    Test.expect(fundBridgeResult, Test.beSucceeded())
    let createCOAResult = executeTransaction(
        "../transactions/evm/create_account.cdc",
        [1000.0],
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
        arguments: [getFactoryBytecode()],
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

    let templateCommitResult = executeTransaction(
        "../transactions/bridge/admin/upsert_contract_code_chunks.cdc",
        ["bridgedNFT", getBridgedNFTTemplateChunks()],
        bridgeAccount
    )
    Test.expect(templateCommitResult, Test.beSucceeded())
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
        arguments: [bridgeAccount.address, "FlowEVMBridge"]
    )
    Test.expect(err, Test.beNil())

    // Fund test accounts
    let fundAliceResult = executeTransaction(
        "../transactions/flow-token/transfer_flow.cdc",
        [alice.address, 100.0],
        serviceAccount
    )
    Test.expect(fundAliceResult, Test.beSucceeded())
    let fundExampleNFTResult = executeTransaction(
        "../transactions/flow-token/transfer_flow.cdc",
        [exampleNFTAccount.address, 100.0],
        serviceAccount
    )
    Test.expect(fundExampleNFTResult, Test.beSucceeded())
    let fundERC721Result = executeTransaction(
        "../transactions/flow-token/transfer_flow.cdc",
        [exampleERC721Account.address, 100.0],
        serviceAccount
    )
    Test.expect(fundERC721Result, Test.beSucceeded())

    // Create COAs in all test accounts, funding from $FLOW balance
    let createAliceCOAResult = executeTransaction(
        "../transactions/evm/create_account.cdc",
        [50.0],
        alice
    )
    Test.expect(createAliceCOAResult, Test.beSucceeded())
    let createExampleNFTCOAResult = executeTransaction(
        "../transactions/evm/create_account.cdc",
        [50.0],
        exampleNFTAccount
    )
    Test.expect(createExampleNFTCOAResult, Test.beSucceeded())
    let createERC721COAResult = executeTransaction(
        "../transactions/evm/create_account.cdc",
        [50.0],
        exampleERC721Account
    )
    Test.expect(createERC721COAResult, Test.beSucceeded())

    // Deploy example assets - ExampleNFT & ExampleERc721
    err = Test.deployContract(
        name: "ExampleNFT",
        path: "../contracts/example-assets/ExampleNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "EVMDeployer",
        path: "../contracts/test/EVMDeployer.cdc",
        arguments: [getERC721Bytecode(), 0.0]
    )
    Test.expect(err, Test.beNil())

    // Setup Alice with ExampleNFT Collection & mint an NFT
    let setupAliceNFTResult = executeTransaction(
        "../transactions/example-assets/setup_collection.cdc",
        [],
        alice
    )
    Test.expect(setupAliceNFTResult, Test.beSucceeded())
    let mintAliceNFTResult = executeTransaction(
        "../transactions/example-assets/mint_nft.cdc",
        [alice.address, "name", "description", "thumbnail", [], [], []],
        exampleNFTAccount
    )
    Test.expect(mintAliceNFTResult, Test.beSucceeded())
    // Mint Alice an ERC721 to their COA
    let aliceCOA = executeScript(
        "../scripts/evm/get_evm_address_string.cdc",
        [alice.address]
    ).returnValue! as! String
    let erc721Address = executeScript(
        "../scripts/test/get_deployed_contract_address_string.cdc",
        []
    ).returnValue! as! String
    let mintAliceERC721Result = executeTransaction(
        "../transactions/example-assets/safe_mint_erc721.cdc",
        [aliceCOA, UInt256(42), "tokenURI",  erc721Address, UInt64(500_000)],
        exampleERC721Account
    )
    Test.expect(mintAliceERC721Result, Test.beSucceeded())
}

access(all)
fun testExampleNFTBridgeOnboardingSucceeds() {
    // TODO
}

access(all)
fun testExampleERC721BridgeOnboardingSucceeds() {
    // TODO
}

access(all)
fun testBridgeNFTToEVMSucceeds() {
    // TODO
}

access(all)
fun testBridgeNFTFromEVMSucceeds() {
    // TODO
}

access(all)
fun testSetBridgeFeeSucceeds() {
    // TODO
}

access(all)
fun testBridgeToEVMWithFeeSucceeds() {
    // TODO
}

access(all)
fun testBridgeFromEVMWithFeeSucceeds() {
    // TODO
}