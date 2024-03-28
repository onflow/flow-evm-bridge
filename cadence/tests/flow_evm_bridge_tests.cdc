import Test
import BlockchainHelpers

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let exampleERC721Account = Test.getAccount(0x0000000000000009)
access(all) let alice = Test.createAccount()

// ExampleNFT values
access(all) let exampleNFTIdentifier = "A.0000000000000008.ExampleNFT.NFT"
access(all) let exampleNFTTokenName = "Example NFT"
access(all) let exampleNFTTokenDescription = "Example NFT token description"
access(all) let exampleNFTTokenThumbnail = "https://examplenft.com/thumbnail.png"

// ERC721 values
access(all) let erc721Name = "NAME"
access(all) let erc721Symbol = "SYMBOL"
access(all) let erc721ID: UInt256 = 42
access(all) let erc721URI = "URI"

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
        arguments: [bridgeAccount.address, "FlowEVMBridge"]
    )
    Test.expect(err, Test.beNil())

    // Transfer ERC721 deployer some $FLOW
    let fundERC721AccountResult = executeTransaction(
        "../transactions/flow-token/transfer_flow.cdc",
        [exampleERC721Account.address, 100.0],
        serviceAccount
    )
    Test.expect(fundERC721AccountResult, Test.beSucceeded())
    // Configure bridge account with a COA
    let createERC721COAResult = executeTransaction(
        "../transactions/evm/create_account.cdc",
        [10.0],
        exampleERC721Account
    )
    Test.expect(createERC721COAResult, Test.beSucceeded())
    // Deploy the ERC721 from EVMDeployer (simply to capture deploye EVM contract address)
    // TODO: Replace this contract with the `deployedContractAddress` value emitted on deployment
    //      once `evm` events Types are available
    err = Test.deployContract(
        name: "EVMDeployer",
        path: "../contracts/test/EVMDeployer.cdc",
        arguments: [getCompiledERC721Bytecode(), UInt(0)]
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "ExampleNFT",
        path: "../contracts/example-assets/ExampleNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

// TODO: Figure out how to test EVMBridgeRouter given it needs to be deployed to the service account
//      and we can't seem to alter service account storage from the test suite
access(all)
fun testIsBridgeRouterConfiguredSucceeds() {
    let isConfiguredResult = executeScript(
        "../scripts/test/is_bridge_router_configured.cdc",
        []
    )
    Test.expect(isConfiguredResult, Test.beSucceeded())
    Test.assertEqual(true, isConfiguredResult.returnValue as! Bool? ?? panic("Problem getting Router"))
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

access(all)
fun testMintExampleNFTSucceeds() {
    let setupCollectionResult = executeTransaction(
        "../transactions/example-assets/setup_collection.cdc",
        [],
        alice
    )
    Test.expect(setupCollectionResult, Test.beSucceeded())

    let mintExampleNFTResult = executeTransaction(
        "../transactions/example-assets/mint_nft.cdc",
        [alice.address, exampleNFTTokenName, exampleNFTTokenDescription, exampleNFTTokenThumbnail, [], [], []],
        exampleNFTAccount
    )
    Test.expect(mintExampleNFTResult, Test.beSucceeded())

    let aliceIDResult = executeScript(
        "../scripts/nft/get_ids.cdc",
        [alice.address, "cadenceExampleNFTCollection"]
    )
    Test.expect(aliceIDResult, Test.beSucceeded())
    let aliceOwnedIDs = aliceIDResult.returnValue as! [UInt64]? ?? panic("Problem getting ExampleNFT IDs")
    Test.assertEqual(1, aliceOwnedIDs.length)
}

access(all)
fun testMintERC721Succeeds() {
    let aliceCOAAddressResult = executeScript(
        "../scripts/evm/get_evm_address_string.cdc",
        [alice.address]
    )
    Test.expect(aliceCOAAddressResult, Test.beSucceeded())
    let aliceCOAAddressString = aliceCOAAddressResult.returnValue as! String? ?? panic("Problem getting COA address as String")
    Test.assertEqual(40, aliceCOAAddressString.length)
    let erc721AddressResult = executeScript(
        "../scripts/test/get_deployed_erc721_address_string.cdc",
        []
    )
    Test.expect(erc721AddressResult, Test.beSucceeded())
    let erc721AddressString = erc721AddressResult.returnValue as! String? ?? panic("Problem getting COA address as String")
    Test.assertEqual(40, erc721AddressString.length)

    let mintERC721Result = executeTransaction(
        "../transactions/example-assets/safe_mint_erc721.cdc",
        [aliceCOAAddressString, erc721ID, erc721URI, erc721AddressString, UInt64(200_000)],
        exampleERC721Account
    )
    Test.expect(mintERC721Result, Test.beSucceeded())
}

access(all)
fun testOnboardByTypeSucceeds() {
    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding.cdc",
        [exampleNFTIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboard_by_type.cdc",
        [exampleNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding.cdc",
        [exampleNFTIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboard_by_type.cdc",
        [exampleNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testOnboardByEVMAddressSucceeds() {
    let erc721AddressResult = executeScript(
        "../scripts/test/get_deployed_erc721_address_string.cdc",
        []
    )
    Test.expect(erc721AddressResult, Test.beSucceeded())
    let erc721AddressString = erc721AddressResult.returnValue as! String? ?? panic("Problem getting COA address as String")
    Test.assertEqual(40, erc721AddressString.length)

    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc721AddressString]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboard_by_evm_address.cdc",
        [erc721AddressString],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    onboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc721AddressString]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboard_by_evm_address.cdc",
        [erc721AddressString],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testBridgeCadenceNativeNFTToEVMSucceeds() {
    let aliceIDResult = executeScript(
        "../scripts/nft/get_ids.cdc",
        [alice.address, "cadenceExampleNFTCollection"]
    )
    Test.expect(aliceIDResult, Test.beSucceeded())
    let aliceOwnedIDs = aliceIDResult.returnValue as! [UInt64]? ?? panic("Problem getting ExampleNFT IDs")
    Test.assertEqual(1, aliceOwnedIDs.length)

    let aliceCOAAddressResult = executeScript(
        "../scripts/evm/get_evm_address_string.cdc",
        [alice.address]
    )
    Test.expect(aliceCOAAddressResult, Test.beSucceeded())
    let aliceCOAAddressString = aliceCOAAddressResult.returnValue as! String? ?? panic("Problem getting COA address as String")
    Test.assertEqual(40, aliceCOAAddressString.length)

    // TODO: This fails because EVMBridgeRouter.Router does not configure a resource in the service account
    let bridgeToEVMResult = executeTransaction(
        "../transactions/bridge/bridge_nft_to_evm.cdc",
        [exampleNFTAccount.address, "ExampleNFT", aliceOwnedIDs[0]],
        alice
    )
    Test.expect(bridgeToEVMResult, Test.beSucceeded())

    var associatedEVMAddressResult = executeScript(
        "../scripts/bridge/get_associated_evm_address.cdc",
        [exampleNFTIdentifier]
    )
    Test.expect(associatedEVMAddressResult, Test.beSucceeded())
    let associatedEVMAddressString = associatedEVMAddressResult.returnValue as! String? ?? panic("Problem getting EVM Address as String")
    Test.assertEqual(40, associatedEVMAddressString.length)

    var isOwnerResult = executeScript(
        "../scripts/utils/is_owner.cdc",
        [UInt256(aliceOwnedIDs[0]), aliceCOAAddressString, associatedEVMAddressString]
    )
    Test.expect(isOwnerResult, Test.beSucceeded())
    Test.assertEqual(true, isOwnerResult.returnValue as! Bool? ?? panic("Problem getting owner status"))
}