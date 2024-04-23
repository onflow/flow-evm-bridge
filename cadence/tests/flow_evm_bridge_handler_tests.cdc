import Test
import BlockchainHelpers

import "FungibleToken"
import "NonFungibleToken"
import "FlowStorageFees"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let exampleERCAccount = Test.getAccount(0x0000000000000009)
access(all) let exampleHandledTokenAccount = Test.getAccount(0x0000000000000011)
access(all) let alice = Test.createAccount()

// ExampleToken
access(all) let exampleTokenIdentifier = "A.0000000000000011.ExampleHandledToken.Vault"
access(all) let exampleTokenMintAmount = 100.0

// ERC20 values
access(all) let erc20MintAmount: UInt256 = 100_000_000_000_000_000_000

// Fee initialiazation values
access(all) let expectedOnboardFee = 1.0
access(all) let expectedBaseFee = 0.001

// Test height snapshot for test state resets
access(all) var snapshot: UInt64 = 0

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

    // Update EVM contract with proposed bridge-supporting COA integration
    let updateResult = executeTransaction(
        "../transactions/test/update_contract.cdc",
        ["EVM", getEVMUpdateCode()],
        serviceAccount
    )
    Test.expect(updateResult, Test.beSucceeded())
    // Transfer bridge account some $FLOW
    transferFlow(signer: serviceAccount, recipient: bridgeAccount.address, amount: 10_000.0)
    // Configure bridge account with a COA
    createCOA(signer: bridgeAccount, fundingAmount: 1_000.0)

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
        name: "CrossVMToken",
        path: "../contracts/bridge/CrossVMToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeHandlerInterfaces",
        path: "../contracts/bridge/FlowEVMBridgeHandlerInterfaces.cdc",
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
        name: "FlowEVMBridgeTokenEscrow",
        path: "../contracts/bridge/FlowEVMBridgeTokenEscrow.cdc",
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
    // Commit bridged Token code
    let bridgedTokenChunkResult = executeTransaction(
        "../transactions/bridge/admin/upsert_contract_code_chunks.cdc",
        ["bridgedToken", getBridgedTokenCodeChunks()],
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
        name: "IEVMBridgeTokenMinter",
        path: "../contracts/bridge/IEVMBridgeTokenMinter.cdc",
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
        name: "IFlowEVMTokenBridge",
        path: "../contracts/bridge/IFlowEVMTokenBridge.cdc",
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
        name: "FlowEVMBridgeAccessor",
        path: "../contracts/bridge/FlowEVMBridgeAccessor.cdc",
        arguments: [serviceAccount.address]
    )
    Test.expect(err, Test.beNil())

    let claimAccessorResult = executeTransaction(
        "../transactions/bridge/admin/claim_accessor_capability_and_save_router.cdc",
        ["FlowEVMBridgeAccessor", bridgeAccount.address],
        serviceAccount
    )
    Test.expect(claimAccessorResult, Test.beSucceeded())

    // Configure example ERC20 account with $FLOW and a COA
    transferFlow(signer: serviceAccount, recipient: exampleERCAccount.address, amount: 1_000.0)
    createCOA(signer: exampleERCAccount, fundingAmount: 10.0)

    // Deploy the ERC20 from EVMDeployer (simply to capture deploye EVM contract address)
    // TODO: Replace this contract with the `deployedContractAddress` value emitted on deployment
    //      once `evm` events Types are available
    err = Test.deployContract(
        name: "EVMDeployer",
        path: "../contracts/test/EVMDeployer.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "ExampleHandledToken",
        path: "../contracts/example-assets/ExampleHandledToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeHandlers",
        path: "../contracts/bridge/FlowEVMBridgeHandlers.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

/* --- ASSET & ACCOUNT SETUP - Configure test accounts with assets to bridge --- */

access(all)
fun testCreateCOASucceeds() {
    transferFlow(signer: serviceAccount, recipient: alice.address, amount: 1_000.0)
    createCOA(signer: alice, fundingAmount: 100.0)

    let coaAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, coaAddressHex.length)
}

// Mint tokens to put some in circulation
access(all)
fun testMintExampleTokenSucceeds() {
    let setupVaultResult = executeTransaction(
        "../transactions/example-assets/example-handled-token/setup_vault.cdc",
        [],
        alice
    )
    Test.expect(setupVaultResult, Test.beSucceeded())

    let mintExampleTokenResult = executeTransaction(
        "../transactions/example-assets/example-handled-token/mint_tokens.cdc",
        [alice.address, exampleTokenMintAmount],
        exampleHandledTokenAccount
    )
    Test.expect(mintExampleTokenResult, Test.beSucceeded())

    let aliceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(exampleTokenMintAmount, aliceBalance)

    let events = Test.eventsOfType(Type<FungibleToken.Deposited>())
    let evt = events[events.length - 1] as! FungibleToken.Deposited

    Test.assertEqual(aliceBalance, evt.amount)
}

// Hand off Minter to bridge handler - bridge then has sole authority to mint based on contract logic
access(all)
fun testConfigureCadenceNativeTokenHandlerSucceeds() {
    let handlerSetupTxn = Test.Transaction(
        code: Test.readFile("../transactions/bridge/admin/create_cadence_native_token_handler.cdc"),
        authorizers: [exampleHandledTokenAccount.address, bridgeAccount.address],
        signers: [exampleHandledTokenAccount, bridgeAccount],
        arguments: [],
    )
    let createHandlerResult = Test.executeTransaction(handlerSetupTxn)
    Test.expect(createHandlerResult, Test.beSucceeded())

    // TODO: Add event validation when EVM and EVM dependent contracts can be imported to Test env
}

// Mint tokens to put some in circulation
access(all)
fun testMintExampleTokenFails() {
    let aliceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(exampleTokenMintAmount, aliceBalance)

    let mintExampleTokenResult = executeTransaction(
        "../transactions/example-assets/example-handled-token/mint_tokens.cdc",
        [alice.address, exampleTokenMintAmount],
        exampleHandledTokenAccount
    )
    Test.expect(mintExampleTokenResult, Test.beFailed())
}

access(all)
fun testDeployERC20Succeeds() {
    let erc20DeployResult = executeTransaction(
        "../transactions/test/deploy_using_evm_deployer.cdc",
        ["erc20", getCompiledERC20Bytecode(), 0 as UInt],
        exampleERCAccount
    )
    Test.expect(erc20DeployResult, Test.beSucceeded())

    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    Test.assertEqual(40, erc20AddressHex.length)
}

access(all)
fun testSetHandlerTargetEVMAddressSucceeds() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    Test.assertEqual(40, erc20AddressHex.length)

    let setHandlerTargetResult = executeTransaction(
        "../transactions/bridge/admin/set_handler_target_evm_address.cdc",
        [exampleTokenIdentifier, erc20AddressHex],
        bridgeAccount
    )
    Test.expect(setHandlerTargetResult, Test.beSucceeded())

    // Check EVM Address associated with Type & vice versa
    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleTokenIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)
    Test.assertEqual(erc20AddressHex, associatedEVMAddressHex)
}

access(all)
fun testMintERC20ToBridgeEscrowSucceeds() {
    let bridgeCOAAddressHex = getBridgeCOAAddressHex()
    let exampleTokenTotalSupplyResult = executeScript(
        "../scripts/example-assets/tokens/total_supply.cdc",
        [exampleHandledTokenAccount.address, "ExampleHandledToken", exampleTokenIdentifier]
    )
    Test.expect(exampleTokenTotalSupplyResult, Test.beSucceeded())
    let exampleTokenTotalSupply = exampleTokenTotalSupplyResult.returnValue as! UFix64?
        ?? panic("Problem getting total supply")
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    Test.assertEqual(40, erc20AddressHex.length)

    let mintERC20Result = executeTransaction(
        "../transactions/example-assets/evm-assets/mint_erc20.cdc",
        [bridgeCOAAddressHex, exampleTokenTotalSupply, erc20AddressHex, UInt64(200_000)],
        exampleERCAccount
    )
    Test.expect(mintERC20Result, Test.beSucceeded())

    let escrowBalance = balanceOf(evmAddressHex: bridgeCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(exampleTokenTotalSupply, escrowBalance)
}

access(all)
fun testMintERC20ToArbitraryRecipientSucceeds() {
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    Test.assertEqual(40, erc20AddressHex.length)

    let mintERC20Result = executeTransaction(
        "../transactions/example-assets/evm-assets/mint_erc20.cdc",
        [aliceCOAAddressHex, erc20MintAmount, erc20AddressHex, UInt64(200_000)],
        exampleERCAccount
    )
    Test.expect(mintERC20Result, Test.beSucceeded())

    let aliceBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, aliceBalance)
}

access(all)
fun testUpdateBridgeFeesSucceeds() {
    let bytesUsed: UInt64 = 1024
    let expectedFinalFee = FlowStorageFees.storageCapacityToFlow(
            FlowStorageFees.convertUInt64StorageBytesToUFix64Megabytes(bytesUsed)
        ) + expectedBaseFee

    // Validate the initialized values are set to 0.0
    var actualOnboardFeeResult = executeScript(
        "../scripts/config/get_onboard_fee.cdc",
        []
    )
    Test.expect(actualOnboardFeeResult, Test.beSucceeded())
    var actualBaseFeeResult = executeScript(
        "../scripts/config/get_base_fee.cdc",
        []
    )
    Test.expect(actualBaseFeeResult, Test.beSucceeded())

    Test.assertEqual(0.0, actualOnboardFeeResult.returnValue as! UFix64? ?? panic("Problem getting onboard fee"))
    Test.assertEqual(0.0, actualBaseFeeResult.returnValue as! UFix64? ?? panic("Problem getting base fee"))

    var actualCalculatedResult = executeScript(
        "../scripts/bridge/calculate_bridge_fee.cdc",
        [bytesUsed]
    )
    Test.expect(actualCalculatedResult, Test.beSucceeded())
    Test.assertEqual(0.0, actualCalculatedResult.returnValue as! UFix64? ?? panic("Problem getting calculated fee"))

    // Set the fees to new values
    let updateOnboardFeeResult = executeTransaction(
        "../transactions/bridge/admin/update_onboard_fee.cdc",
        [expectedOnboardFee],
        bridgeAccount
    )
    Test.expect(updateOnboardFeeResult, Test.beSucceeded())
    let updateBaseFeeResult = executeTransaction(
        "../transactions/bridge/admin/update_base_fee.cdc",
        [expectedBaseFee],
        bridgeAccount
    )
    Test.expect(updateBaseFeeResult, Test.beSucceeded())

    // Validate the values have been updated
    actualOnboardFeeResult = executeScript(
        "../scripts/config/get_onboard_fee.cdc",
        []
    )
    Test.expect(actualOnboardFeeResult, Test.beSucceeded())
    actualBaseFeeResult = executeScript(
        "../scripts/config/get_base_fee.cdc",
        []
    )
    Test.expect(actualBaseFeeResult, Test.beSucceeded())

    Test.assertEqual(expectedOnboardFee, actualOnboardFeeResult.returnValue as! UFix64? ?? panic("Problem getting onboard fee"))
    Test.assertEqual(expectedBaseFee, actualBaseFeeResult.returnValue as! UFix64? ?? panic("Problem getting base fee"))

    actualCalculatedResult = executeScript(
        "../scripts/bridge/calculate_bridge_fee.cdc",
        [bytesUsed]
    )
    Test.expect(actualCalculatedResult, Test.beSucceeded())
    Test.assertEqual(expectedFinalFee, actualCalculatedResult.returnValue as! UFix64? ?? panic("Problem getting calculated fee"))

}

/* --- ONBOARDING - Test asset onboarding to the bridge --- */

access(all)
fun testOnboardHandledTokenByTypeFails() {
    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding_by_identifier.cdc",
        [exampleTokenIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testOnboardHandledERC20ByEVMAddressFails() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    Test.assertEqual(40, erc20AddressHex.length)

    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc20AddressHex]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc20AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

/* --- BRIDGING FUNGIBLE TOKENS - Test bridging both Cadence- & EVM-native fungible tokens --- */

// TODO - bridge to EVM fails
// TODO - bridge from EVM fails
// TODO - handler enable bridging succeeds
// TODO - snapshot
// TODO - bridge all funds to EVM succeeds
// TODO - bridge from EVM succeeds
// TODO - reset to snapshot
// TODO - bridge all funds from EVM succeeds
// TODO - bridge to EVM succeeds
