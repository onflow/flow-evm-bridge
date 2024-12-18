import Test
import BlockchainHelpers

import "FungibleToken"
import "NonFungibleToken"
import "FlowStorageFees"
import "EVM"
import "FlowEVMBridgeConfig"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleERCAccount = Test.getAccount(0x0000000000000009)
access(all) let alice = Test.createAccount()
access(all) var aliceCOAAddressHex: String = ""

// FlowToken
access(all) let flowTokenAccountAddress = Address(0x0000000000000003)
access(all) let flowTokenIdentifier = "A.0000000000000003.FlowToken.Vault"
access(all) let flowFundingAmount = 201.0
access(all) let coaFundingAmount = 100.0

// WFLOW values
access(all) var wflowAddressHex: String = ""
access(all) let erc20MintAmount: UInt256 = 100_000_000_000_000_000_000
access(all) let wrapFlowAmount: UFix64 = 100.0

// Fee initialiazation values
access(all) let expectedOnboardFee = 1.0
access(all) let expectedBaseFee = 0.001

// Default decimals for Cadence UFix64 values
access(all) let defaultDecimals: UInt8 = 18

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
        name: "ICrossVMAsset",
        path: "../contracts/bridge/interfaces/ICrossVMAsset.cdc",
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

    // Deploy FlowBridgeFactory.sol
    let deploymentResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getCompiledFactoryBytecode(), 15_000_000, 0.0],
        bridgeAccount
    )
    // Get the deployed contract address from the latest EVM event
    let evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    Test.assertEqual(2, evts.length)
    let factoryAddressHex = getEVMAddressHexFromEvents(evts, idx: 0)

    err = Test.deployContract(
        name: "FlowEVMBridgeUtils",
        path: "../contracts/bridge/FlowEVMBridgeUtils.cdc",
        arguments: [factoryAddressHex]
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeResolver",
        path: "../contracts/bridge/FlowEVMBridgeResolver.cdc",
        arguments: []
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
        "../transactions/bridge/admin/templates/upsert_contract_code_chunks.cdc",
        ["bridgedNFT", getBridgedNFTCodeChunks()],
        bridgeAccount
    )
    Test.expect(bridgedNFTChunkResult, Test.beSucceeded())
    // Commit bridged Token code
    let bridgedTokenChunkResult = executeTransaction(
        "../transactions/bridge/admin/templates/upsert_contract_code_chunks.cdc",
        ["bridgedToken", getBridgedTokenCodeChunks()],
        bridgeAccount
    )
    Test.expect(bridgedNFTChunkResult, Test.beSucceeded())

    err = Test.deployContract(
        name: "IEVMBridgeNFTMinter",
        path: "../contracts/bridge/interfaces/IEVMBridgeNFTMinter.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "IEVMBridgeTokenMinter",
        path: "../contracts/bridge/interfaces/IEVMBridgeTokenMinter.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "IFlowEVMNFTBridge",
        path: "../contracts/bridge/interfaces/IFlowEVMNFTBridge.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "IFlowEVMTokenBridge",
        path: "../contracts/bridge/interfaces/IFlowEVMTokenBridge.cdc",
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
        "../transactions/bridge/admin/evm-integration/claim_accessor_capability_and_save_router.cdc",
        ["FlowEVMBridgeAccessor", bridgeAccount.address],
        serviceAccount
    )
    Test.expect(claimAccessorResult, Test.beSucceeded())

    err = Test.deployContract(
        name: "FlowEVMBridgeHandlers",
        path: "../contracts/bridge/FlowEVMBridgeHandlers.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Set bridge fees
    let updateOnboardFeeResult = executeTransaction(
        "../transactions/bridge/admin/fee/update_onboard_fee.cdc",
        [expectedOnboardFee],
        bridgeAccount
    )
    Test.expect(updateOnboardFeeResult, Test.beSucceeded())
    let updateBaseFeeResult = executeTransaction(
        "../transactions/bridge/admin/fee/update_base_fee.cdc",
        [expectedBaseFee],
        bridgeAccount
    )
    Test.expect(updateBaseFeeResult, Test.beSucceeded())

    // Unpause Bridge
    updateBridgePauseStatus(signer: bridgeAccount, pause: false)
}

/* --- ASSET & ACCOUNT SETUP - Configure test accounts with assets to bridge --- */

// Create a COA in Alice's account who will be the test asset owner for both Cadence & ERC20 FTs
access(all)
fun testCreateCOASucceeds() {
    // Alice's account gets 201.0 FLOW
    transferFlow(signer: serviceAccount, recipient: alice.address, amount: flowFundingAmount)
    // Fund the COA with 100.0 FLOW of the 201.0 FLOW in Alice's account
    createCOA(signer: alice, fundingAmount: coaFundingAmount)

    aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
}

// WFLOW deploys successfully - this will be used as the targetEVMAddress in our TokenHandler
access(all)
fun testDeployWFLOWSucceeds() {
    // Anyone can deploy WFLOW as its unowned - we just use any account here to deploy
    let wflowDeployResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getCompiledWFLOWBytecode(), UInt64(15_000_000), 0.0],
        alice
    )
    Test.expect(wflowDeployResult, Test.beSucceeded())

    let evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    Test.assertEqual(5, evts.length)
    wflowAddressHex = getEVMAddressHexFromEvents(evts, idx: 4)
    log("WFLOW Address: ".concat(wflowAddressHex))
}

access(all)
fun testWrapFLOWSucceeds() {
    let wrapResult = executeTransaction(
        "../transactions/example-assets/evm-assets/wrap_flow.cdc",
        [wflowAddressHex, coaFundingAmount],
        alice
    )
    Test.expect(wrapResult, Test.beSucceeded())

    // Validate that the wrapping was successful by getting alice's COA's WFLOW balance
    let wflowBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: wflowAddressHex)

    // Get WFLOW total supply
    let wflowTotalSupply = getEVMTotalSupply(erc20AddressHex: wflowAddressHex)
    let coaFundingAmountUInt = ufix64ToUInt256(coaFundingAmount, decimals: defaultDecimals)
    Test.assertEqual(coaFundingAmountUInt, wflowBalance)
}

// Configuring the Handler also disables onboarding of WFLOW to the bridge
access(all)
fun testCreateWFLOWTokenHandlerSucceeds() {
    // Create TokenHandler for WFLOW, specifying the target type and expected minter type
    let createHandlerResult = executeTransaction(
        "../transactions/bridge/admin/token-handler/create_wflow_token_handler.cdc",
        [wflowAddressHex],
        bridgeAccount
    )
    Test.expect(createHandlerResult, Test.beSucceeded())

    // TODO: Add event validation when EVM and EVM dependent contracts can be imported to Test env
}

// /* --- ONBOARDING - Test asset onboarding to the bridge --- */

// Since the type has a TokenHandler, onboarding should fail
access(all)
fun testOnboardFlowTokenByTypeFails() {
    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding_by_identifier.cdc",
        [flowTokenIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    // Should fail since request routes to TokenHandler and it's not enabled
    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [flowTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

// Since the WFLOW Address has a TokenHandler, onboarding should fail
access(all)
fun testOnboardWFLOWByEVMAddressFails() {

    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [wflowAddressHex]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    // Should fails since request routes to TokenHandler and it's not enabled
    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [wflowAddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

/* --- BRIDGING FLOW to EVM as WFLOW and WFLOW from EVM as FLOW --- */

// Now enable TokenHandler to bridge in both directions
access(all)
fun testEnableWFLOWTokenHandlerSucceeds() {
    let enabledResult = executeTransaction(
        "../transactions/bridge/admin/token-handler/enable_token_handler.cdc",
        [flowTokenIdentifier],
        bridgeAccount
    )
    Test.expect(enabledResult, Test.beSucceeded())
    // TODO: Validate event emission and values
}

// Validate that funds can be bridged from Cadence to EVM, resulting in balance increase in WFLOW as target
access(all)
fun testBridgeZeroFLOWTokenToEVMFails() {
    // Attempt bridge 0 FLOW to EVM - should fail
    bridgeTokensToEVM(
        signer: alice,
        vaultIdentifier: buildTypeIdentifier(
            address: flowTokenAccountAddress,
            contractName: "FlowToken",
            resourceName: "Vault"
        ),
        amount: 0.0,
        beFailed: true
    )
}

// Validate that funds can be bridged from Cadence to EVM, resulting in balance increase in WFLOW as target
access(all)
fun testBridgeFLOWTokenToEVMFirstSucceeds() {
    snapshot = getCurrentBlockHeight()

    // Take note of the total supply before bridging
    let wflowTotalSupplyBefore = getEVMTotalSupply(erc20AddressHex: wflowAddressHex)

    var cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "flowTokenVault")
        ?? panic("Problem getting FlowToken balance")
    Test.assert(cadenceBalance == flowFundingAmount - coaFundingAmount, message: "Invalid Cadence balance")
    // Leave some FLOW as it's needed for storage, transaction, and bridge fees
    let remainder = 1.0
    let bridgeAmount = cadenceBalance - remainder

    // Convert the bridge amount to UInt256 for EVM balance comparison
    let coaFundingAmountUInt = ufix64ToUInt256(coaFundingAmount, decimals: defaultDecimals)
    let uintBridgeAmount = ufix64ToUInt256(bridgeAmount, decimals: defaultDecimals)

    // Execute bridge to EVM
    bridgeTokensToEVM(
        signer: alice,
        vaultIdentifier: buildTypeIdentifier(
            address: flowTokenAccountAddress,
            contractName: "FlowToken",
            resourceName: "Vault"
        ),
        amount: bridgeAmount,
        beFailed: false
    )

    // Confirm ownership on EVM side with Alice COA as owner of bridged WFLOW
    let evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: wflowAddressHex)
    Test.assertEqual(coaFundingAmountUInt + uintBridgeAmount, evmBalance) // bridged balance + previously minted ERC20

    // Validate that the WFLOW balance in circulation increased by the amount bridged
    let wflowTotalSupplyAfter = getEVMTotalSupply(erc20AddressHex: wflowAddressHex)
    Test.assertEqual(wflowTotalSupplyBefore, wflowTotalSupplyAfter - uintBridgeAmount)

    // Ensure that Alice's WFLOW balance is the sum of the minted amount and the amount bridged
    let aliceEVMBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: wflowAddressHex)
    Test.assertEqual(coaFundingAmountUInt + uintBridgeAmount, aliceEVMBalance)
}

// With all funds now in EVM, we can test bridging back to Cadence
access(all)
fun testBridgeZeroWFLOWTokenFromEVMSecondFails() {
    bridgeTokensFromEVM(
        signer: alice,
        vaultIdentifier: buildTypeIdentifier(
            address: flowTokenAccountAddress,
            contractName: "FlowToken",
            resourceName: "Vault"
        ),
        amount: UInt256(0),
        beFailed: true
    )
}

// With all funds now in EVM, we can test bridging back to Cadence
access(all)
fun testBridgeWFLOWTokenFromEVMSecondSucceeds() {
    // let wflowTotalSupplyBefore = getEVMTotalSupply(erc20AddressHex: wflowAddressHex)

    let cadenceBalanceBefore = getBalance(ownerAddr: alice.address, storagePathIdentifier: "flowTokenVault")
        ?? panic("Problem getting FlowToken balance")

    // Execute bridge from EVM, bridging Alice's full balance to Cadence
    let wflowBalanceBefore = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: wflowAddressHex)
    let ufixEVMbalance = uint256ToUFix64(wflowBalanceBefore, decimals: defaultDecimals)
    bridgeTokensFromEVM(
        signer: alice,
        vaultIdentifier: buildTypeIdentifier(
            address: flowTokenAccountAddress,
            contractName: "FlowToken",
            resourceName: "Vault"
        ),
        amount: wflowBalanceBefore,
        beFailed: false
    )

    // Confirm that Alice's balance has been bridged to Cadence
    let cadenceBalanceAfter = getBalance(ownerAddr: alice.address, storagePathIdentifier: "flowTokenVault")
        ?? panic("Problem getting FlowToken balance")
    let expectedBalanceAfter = cadenceBalanceBefore + ufixEVMbalance - FlowEVMBridgeConfig.baseFee
    Test.assertEqual(expectedBalanceAfter, cadenceBalanceAfter)

    // Confirm that the WFLOW balance was transferred out in the process of bridging
    let evmBalanceAfter = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: wflowAddressHex)
    Test.assertEqual(UInt256(0), evmBalanceAfter)

    // Validate that the WFLOW supply in circulation reduced to 0
    let wflowTotalSupplyAfter = getEVMTotalSupply(erc20AddressHex: wflowAddressHex)
    Test.assertEqual(UInt256(0), wflowTotalSupplyAfter)

    // Validate that all WFLOW funds are now in escrow since all bridged to Cadence
    let escrowBalance = balanceOf(evmAddressHex: getBridgeCOAAddressHex(), erc20AddressHex: wflowAddressHex)
    Test.assertEqual(wflowTotalSupplyAfter, escrowBalance)
}

access(all)
fun testBridgeWFLOWToCadenceAfterDisablingFails() {
    let disabledResult = executeTransaction(
        "../transactions/bridge/admin/token-handler/disable_token_handler.cdc",
        [flowTokenIdentifier],
        bridgeAccount
    )
    Test.expect(disabledResult, Test.beSucceeded())

    let cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "flowTokenVault")
        ?? panic("Problem getting FlowToken balance")

    bridgeTokensToEVM(
        signer: alice,
        vaultIdentifier: buildTypeIdentifier(
            address: flowTokenAccountAddress,
            contractName: "FlowToken",
            resourceName: "Vault"
        ),
        amount: cadenceBalance,
        beFailed: true
    )
}