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
    setupBridge(bridgeAccount: bridgeAccount, serviceAccount: serviceAccount, unpause: true)
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
    Test.assertEqual(21, evts.length)
    wflowAddressHex = getEVMAddressHexFromEvents(evts, idx: evts.length - 1)
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
    onboardByTypeIdentifier(signer: alice, typeIdentifier: flowTokenIdentifier, beFailed: true)
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
    onboardByEVMAddress(signer: alice, evmAddressHex: wflowAddressHex, beFailed: true)
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