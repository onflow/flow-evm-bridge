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
access(all) let exampleTokenMinterIdentifier = "A.0000000000000011.ExampleHandledToken.Minter"
access(all) let exampleTokenMintAmount = 100.0

// ERC20 values
access(all) let erc20MintAmount: UInt256 = 100_000_000_000_000_000_000

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
    err = Test.deployContract(
        name: "EVMUtils",
        path: "../contracts/utils/EVMUtils.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Update EVM contract with proposed bridge-supporting COA integration
    let updateResult = executeTransaction(
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
        "../transactions/bridge/admin/evm/claim_accessor_capability_and_save_router.cdc",
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
        path: "./contracts/EVMDeployer.cdc",
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
}

/* --- ASSET & ACCOUNT SETUP - Configure test accounts with assets to bridge --- */

// Create a COA in Alice's account who will be the test asset owner for both Cadence & ERC20 FTs
access(all)
fun testCreateCOASucceeds() {
    transferFlow(signer: serviceAccount, recipient: alice.address, amount: 1_000.0)
    createCOA(signer: alice, fundingAmount: 100.0)

    let coaAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
}

// Mint tokens to put some in circulation in Cadence
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
// Configuring the Handler also disables onboarding of the Cadence-native token to the bridge
access(all)
fun testConfigureCadenceNativeTokenHandlerSucceeds() {
    // Create TokenHandler for ExampleHandledToken, specifying the target type and expected minter type
    let createHandlerResult = executeTransaction(
        "../transactions/bridge/admin/token-handler/create_cadence_native_token_handler.cdc",
        [exampleTokenIdentifier, exampleTokenMinterIdentifier],
        bridgeAccount
    )
    Test.expect(createHandlerResult, Test.beSucceeded())

    // TODO: Add event validation when EVM and EVM dependent contracts can be imported to Test env
}

// Set the minter in the configured TokenHandler
access(all)
fun testSetTokenHandlerMinterSucceeds() {
    let setHandlerMinterResult = executeTransaction(
        "../transactions/bridge/admin/token-handler/set_token_handler_minter.cdc",
        [exampleTokenIdentifier, /storage/exampleTokenAdmin, bridgeAccount.address],
        exampleHandledTokenAccount
    )
    Test.expect(setHandlerMinterResult, Test.beSucceeded())
}

// ExampleHandledToken no longer has minter after handoff, so minting should fail
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

// Should not be able to enable TokenHandler without targetEVMAddress set
access(all)
fun testEnableTokenHandlerFails() {
    let enabledResult = executeTransaction(
        "../transactions/bridge/admin/token-handler/enable_token_handler.cdc",
        [exampleTokenIdentifier],
        bridgeAccount
    )
    Test.expect(enabledResult, Test.beFailed())
}

// ERC20 deploys successfully - this will be used as the targetEVMAddress in our TokenHandler
access(all)
fun testDeployERC20Succeeds() {
    let erc20DeployResult = executeTransaction(
        "./transactions/deploy_using_evm_deployer.cdc",
        ["erc20", getCompiledERC20Bytecode(), 0 as UInt],
        exampleERCAccount
    )
    Test.expect(erc20DeployResult, Test.beSucceeded())

    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
}

// Set the TokenHandler's targetEVMAddress to the deployed ERC20 contract address
// This will filter requests to onboard the ERC20 to the bridge as the Cadence-nat
access(all)
fun testSetHandlerTargetEVMAddressSucceeds() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")

    let setHandlerTargetResult = executeTransaction(
        "../transactions/bridge/admin/token-handler/set_handler_target_evm_address.cdc",
        [exampleTokenIdentifier, erc20AddressHex],
        bridgeAccount
    )
    Test.expect(setHandlerTargetResult, Test.beSucceeded())

    // Check EVM Address associated with Type & vice versa
    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleTokenIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)
    Test.assertEqual(erc20AddressHex, associatedEVMAddressHex)
}

// Mint ERC20 tokens to bridge escrow so requests from Cadence to EVM can be fulfilled
access(all)
fun testMintERC20ToBridgeEscrowSucceeds() {
    let bridgeCOAAddressHex = getBridgeCOAAddressHex()
    let exampleTokenTotalSupply = getCadenceTotalSupply(
            contractAddress: exampleHandledTokenAccount.address,
            contractName: "ExampleHandledToken",
            vaultIdentifier: exampleTokenIdentifier
        ) ?? panic("Problem getting total supply of Cadence tokens")
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")

    // Convert total supply UFix64 to UInt256 for ERC20 minting
    let uintTotalSupply = ufix64ToUInt256(exampleTokenTotalSupply, decimals: defaultDecimals)

    let mintERC20Result = executeTransaction(
        "../transactions/example-assets/evm-assets/mint_erc20.cdc",
        [bridgeCOAAddressHex, uintTotalSupply, erc20AddressHex, UInt64(200_000)],
        exampleERCAccount
    )
    Test.expect(mintERC20Result, Test.beSucceeded())

    let escrowBalance = balanceOf(evmAddressHex: bridgeCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(uintTotalSupply, escrowBalance)
}

// Mint ERC20 tokens to Alice's COA so she can bridge them to the Cadence
access(all)
fun testMintERC20ToArbitraryRecipientSucceeds() {
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")

    let mintERC20Result = executeTransaction(
        "../transactions/example-assets/evm-assets/mint_erc20.cdc",
        [aliceCOAAddressHex, erc20MintAmount, erc20AddressHex, UInt64(200_000)],
        exampleERCAccount
    )
    Test.expect(mintERC20Result, Test.beSucceeded())

    let aliceBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, aliceBalance)
}

/* --- ONBOARDING - Test asset onboarding to the bridge --- */

// Since the type has a TokenHandler, onboarding should fail
access(all)
fun testOnboardHandledTokenByTypeFails() {
    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding_by_identifier.cdc",
        [exampleTokenIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    // Should fails since request routes to TokenHandler and it's not enabled
    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

// Since the erc20 Address has a TokenHandler, onboarding should fail
access(all)
fun testOnboardHandledERC20ByEVMAddressFails() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")

    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc20AddressHex]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    // Should fails since request routes to TokenHandler and it's not enabled
    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc20AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

/* --- BRIDGING FUNGIBLE TOKENS - Test bridging both Cadence- & EVM-native fungible tokens --- */

// Bridging to EVM before TokenHandler is enabled should fail
access(all)
fun testBridgeHandledCadenceNativeTokenToEVMFails() {
    var cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assert(cadenceBalance == exampleTokenMintAmount)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Execute bridge to EVM - should fail since Handler is not enabled
    bridgeTokensToEVM(
        signer: alice,
        contractAddr: exampleHandledTokenAccount.address,
        contractName: "ExampleHandledToken",
        amount: cadenceBalance,
        beFailed: true
    )
}

// Bridging frrom EVM before TokenHandler is enabled should fail
access(all)
fun testBridgeHandledCadenceNativeTokenFromEVMFails() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    var evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, evmBalance)

    // Execute bridge from EVM
    bridgeTokensFromEVM(
        signer: alice,
        contractAddr: exampleHandledTokenAccount.address,
        contractName: "ExampleHandledToken",
        amount: evmBalance,
        beFailed: true
    )
}

// Now enable TokenHandler to bridge in both directions
access(all)
fun testEnableTokenHandlerSucceeds() {
    let enabledResult = executeTransaction(
        "../transactions/bridge/admin/token-handler/enable_token_handler.cdc",
        [exampleTokenIdentifier],
        bridgeAccount
    )
    Test.expect(enabledResult, Test.beSucceeded())
    // TODO: Validate event emission and values
}

// Validate that funds can be bridged from Cadence to EVM, resulting in balance increase in deployed ERC20 as target
access(all)
fun testBridgeHandledCadenceNativeTokenToEVMFirstSucceeds() {
    snapshot = getCurrentBlockHeight()

    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    let erc20TotalSupplyBefore = getEVMTotalSupply(erc20AddressHex: erc20AddressHex)

    // Alice was the only recipient, so their balance should be the total supply
    var exampleTokenTotalSupply = getCadenceTotalSupply(
            contractAddress: exampleHandledTokenAccount.address,
            contractName: "ExampleHandledToken",
            vaultIdentifier: exampleTokenIdentifier
        ) ?? panic("Problem getting total supply of Cadence tokens")

    let cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assert(cadenceBalance == exampleTokenMintAmount)
    Test.assert(cadenceBalance == exampleTokenTotalSupply)
    let uintCadenceBalance = ufix64ToUInt256(cadenceBalance, decimals: defaultDecimals)

    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Execute bridge to EVM
    bridgeTokensToEVM(
        signer: alice,
        contractAddr: exampleHandledTokenAccount.address,
        contractName: "ExampleHandledToken",
        amount: cadenceBalance,
        beFailed: false
    )

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    let evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount + uintCadenceBalance, evmBalance) // bridged balance + previously minted ERC20

    // Validate that the originally minted tokens were burned in the process of bridging
    exampleTokenTotalSupply = getCadenceTotalSupply(
            contractAddress: exampleHandledTokenAccount.address,
            contractName: "ExampleHandledToken",
            vaultIdentifier: exampleTokenIdentifier
        ) ?? panic("Problem getting total supply of Cadence tokens")
    Test.assertEqual(0.0, exampleTokenTotalSupply)

    // Validate that the ERC20 balance in circulation remained the same
    let erc20TotalSupplyAfter = getEVMTotalSupply(erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20TotalSupplyBefore, erc20TotalSupplyAfter)

    let escrowBalance = balanceOf(evmAddressHex: getBridgeCOAAddressHex(), erc20AddressHex: erc20AddressHex)
    // Validate that there are no funds now in escrow since total Cadence circulation was bridged to EVM
    Test.assertEqual(UInt256(0), escrowBalance)
}

// With all funds now in EVM, we can test bridging back to Cadence
access(all)
fun testBridgeHandledCadenceNativeTokenFromEVMSecondSucceeds() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    let erc20TotalSupplyBefore = getEVMTotalSupply(erc20AddressHex: erc20AddressHex)

    // Execute bridge from EVM, bridging Alice's full balance to Cadence
    let evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    let ufixEVMbalance = uint256ToUFix64(evmBalance, decimals: defaultDecimals)
    bridgeTokensFromEVM(
        signer: alice,
        contractAddr: exampleHandledTokenAccount.address,
        contractName: "ExampleHandledToken",
        amount: evmBalance,
        beFailed: false
    )

    // Confirm that Alice's balance is now the total supply
    let cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(ufixEVMbalance, cadenceBalance)

    // Confirm that the ERC20 balance was burned in the process of bridging
    let evmBalanceAfter = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(UInt256(0), evmBalanceAfter)

    // Validate that the ERC20 balance in circulation remained the same
    let erc20TotalSupplyAfter = getEVMTotalSupply(erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20TotalSupplyBefore, erc20TotalSupplyAfter)

    // Validate that all ERC20 funds are now in escrow since all bridged to Cadence
    let escrowBalance = balanceOf(evmAddressHex: getBridgeCOAAddressHex(), erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20TotalSupplyAfter, escrowBalance)
}

// Now test bridging with liquidity flow moving entirely from EVM to Cadence and back
access(all)
fun testBridgeHandledCadenceNativeTokenFromEVMFirstSucceeds() {
    // Reset to snapshot before bridging between VMs
    Test.reset(to: snapshot)

    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    var erc20TotalSupplyBefore = getEVMTotalSupply(erc20AddressHex: getDeployedAddressFromDeployer(name: "erc20"))
    let cadenceTotalSupplyBefore = getCadenceTotalSupply(
            contractAddress: exampleHandledTokenAccount.address,
            contractName: "ExampleHandledToken",
            vaultIdentifier: exampleTokenIdentifier
        ) ?? panic("Problem getting total supply of Cadence tokens")
    let uintCadenceTotalSupplyBefore = ufix64ToUInt256(cadenceTotalSupplyBefore, decimals: defaultDecimals)
    Test.assertEqual(uintCadenceTotalSupplyBefore + erc20MintAmount, erc20TotalSupplyBefore)

    // Alice should start with amount previously minted
    let aliceEVMBalanceBefore = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, aliceEVMBalanceBefore)
    // Cadence total supply should match the amount in escrow
    let escrowBalanceBefore = balanceOf(evmAddressHex: getBridgeCOAAddressHex(), erc20AddressHex: erc20AddressHex)
    Test.assertEqual(uintCadenceTotalSupplyBefore, escrowBalanceBefore)

    // Alice was the only one minted Cadence tokens, so should have the total supply in Cadence
    let aliceCadenceBalanceBefore = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(exampleTokenMintAmount, aliceCadenceBalanceBefore)
    Test.assertEqual(cadenceTotalSupplyBefore, aliceCadenceBalanceBefore)

    // Convert the bridge amount to UFix64 for Cadence balance comparison
    let ufixBridgeAmount = uint256ToUFix64(erc20MintAmount, decimals: defaultDecimals)

    // Execute bridge from EVM
    bridgeTokensFromEVM(
        signer: alice,
        contractAddr: exampleHandledTokenAccount.address,
        contractName: "ExampleHandledToken",
        amount: aliceEVMBalanceBefore,
        beFailed: false
    )

    // Confirm that Alice's balance is now the total supply, having incremented by the amount bridged into Cadence
    let aliceCadenceBalanceAfter = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    let cadenceTotalSupplyAfter = getCadenceTotalSupply(
            contractAddress: exampleHandledTokenAccount.address,
            contractName: "ExampleHandledToken",
            vaultIdentifier: exampleTokenIdentifier
        ) ?? panic("Problem getting total supply of Cadence tokens")
    Test.assertEqual(cadenceTotalSupplyAfter, aliceCadenceBalanceAfter)
    Test.assertEqual(cadenceTotalSupplyAfter, cadenceTotalSupplyBefore + ufixBridgeAmount)

    // Confirm Alice's EVM balance is now 0
    let aliceEVMBalanceAfter = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(UInt256(0), aliceEVMBalanceAfter)

    // Confirm that the amount in escrow incremented
    let escrowBalanceAfter = balanceOf(evmAddressHex: getBridgeCOAAddressHex(), erc20AddressHex: erc20AddressHex)
    Test.assertEqual(escrowBalanceBefore + aliceEVMBalanceBefore, escrowBalanceAfter)

    // Ensure the ERC20 balance in circulation remained the same
    let erc20TotalSupplyAfter = getEVMTotalSupply(erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20TotalSupplyBefore, erc20TotalSupplyAfter)
}

// Now return all liquidity back to EVM
access(all)
fun testBridgeHandledCadenceNativeTokenToEVMSecondSucceeds() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    let erc20TotalSupplyBefore = getEVMTotalSupply(erc20AddressHex: erc20AddressHex)

    // Alice should start with amount previously minted
    let aliceEVMBalanceBefore = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(UInt256(0), aliceEVMBalanceBefore)
    let aliceCadenceBalanceBefore = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")

    // Convert the bridge amount to UInt256 for EVM balance comparison
    let uintBridgeAmount = ufix64ToUInt256(aliceCadenceBalanceBefore, decimals: defaultDecimals)

    // Execute bridge to EVM
    bridgeTokensToEVM(
        signer: alice,
        contractAddr: exampleHandledTokenAccount.address,
        contractName: "ExampleHandledToken",
        amount: aliceCadenceBalanceBefore,
        beFailed: false
    )

    let aliceCadenceBalanceAfter = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(0.0, aliceCadenceBalanceAfter)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    let aliceEVMBalanceAfter = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(uintBridgeAmount, aliceEVMBalanceAfter)

    // Confirm that the ERC20 balance in circulation remained the same
    let erc20TotalSupplyAfter = getEVMTotalSupply(erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20TotalSupplyBefore, erc20TotalSupplyAfter)

    // Confirm escrow balance is now 0
    let escrowBalance = balanceOf(evmAddressHex: getBridgeCOAAddressHex(), erc20AddressHex: erc20AddressHex)
    Test.assertEqual(UInt256(0), escrowBalance)
}
