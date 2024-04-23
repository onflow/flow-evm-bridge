import Test
import BlockchainHelpers

import "FungibleToken"
import "NonFungibleToken"
import "ExampleNFT"
import "ExampleToken"
import "FlowStorageFees"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let exampleERCAccount = Test.getAccount(0x0000000000000009)
access(all) let exampleTokenAccount = Test.getAccount(0x0000000000000010)
access(all) let alice = Test.createAccount()

// ExampleNFT values
access(all) let exampleNFTIdentifier = "A.0000000000000008.ExampleNFT.NFT"
access(all) let exampleNFTTokenName = "Example NFT"
access(all) let exampleNFTTokenDescription = "Example NFT token description"
access(all) let exampleNFTTokenThumbnail = "https://examplenft.com/thumbnail.png"
access(all) var mintedNFTID: UInt64 = 0

// ExampleToken
access(all) let exampleTokenIdentifier = "A.0000000000000010.ExampleToken.Vault"
access(all) let exampleTokenMintAmount = 100.0

// ERC721 values
access(all) let erc721Name = "NAME"
access(all) let erc721Symbol = "SYMBOL"
access(all) let erc721ID: UInt256 = 42
access(all) let erc721URI = "URI"

// ERC20 values
access(all) let erc20MintAmount: UInt256 = 100_000_000_000_000_000_000 // 100.0 as uint256 (100e18)

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

    // Configure example ERC20 account with a COA
    transferFlow(signer: serviceAccount, recipient: exampleERCAccount.address, amount: 1_000.0)
    createCOA(signer: exampleERCAccount, fundingAmount: 10.0)

    // Deploy the ERC20/721 from EVMDeployer (simply to capture deploye EVM contract address)
    // TODO: Replace this contract with the `deployedContractAddress` value emitted on deployment
    //      once `evm` events Types are available
    err = Test.deployContract(
        name: "EVMDeployer",
        path: "../contracts/test/EVMDeployer.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    let erc721DeployResult = executeTransaction(
        "../transactions/test/deploy_using_evm_deployer.cdc",
        ["erc721", getCompiledERC721Bytecode(), 0 as UInt],
        exampleERCAccount
    )
    Test.expect(erc721DeployResult, Test.beSucceeded())
    let erc20DeployResult = executeTransaction(
        "../transactions/test/deploy_using_evm_deployer.cdc",
        ["erc20", getCompiledERC20Bytecode(), 0 as UInt],
        exampleERCAccount
    )
    Test.expect(erc20DeployResult, Test.beSucceeded())
    err = Test.deployContract(
        name: "ExampleNFT",
        path: "../contracts/example-assets/ExampleNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "ExampleToken",
        path: "../contracts/example-assets/ExampleToken.cdc",
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

access(all)
fun testBridgeFlowToEVMSucceeds() {
    // Get $FLOW balances before, making assertions based on values from previous case
    let cadenceBalanceBefore = getBalance(ownerAddr: alice.address, storagePathIdentifier: "flowTokenVault")
        ?? panic("Problem getting $FLOW balance")
    Test.assertEqual(900.0, cadenceBalanceBefore)

    // Get EVM $FLOW balance before
    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    let evmBalanceBefore = getEVMFlowBalance(of: aliceCOAAddressHex)
    Test.assertEqual(100.0, evmBalanceBefore)

    // Execute bridge to EVM
    let bridgeAmount = 100.0
    bridgeTokensToEVM(
        signer: alice,
        contractAddr: Address(0x03),
        contractName: "FlowToken",
        amount: bridgeAmount
    )

    // Confirm Alice's token balance is now 0.0
    let cadenceBalanceAfter = getBalance(ownerAddr: alice.address, storagePathIdentifier: "flowTokenVault")
        ?? panic("Problem getting $FLOW balance")
    Test.assertEqual(cadenceBalanceBefore - bridgeAmount, cadenceBalanceAfter)

    // Confirm balance on EVM side has been updated
    let evmBalanceAfter = getEVMFlowBalance(of: aliceCOAAddressHex)
    Test.assertEqual(evmBalanceBefore + bridgeAmount, evmBalanceAfter)
}

access(all)
fun testMintExampleNFTSucceeds() {
    let setupCollectionResult = executeTransaction(
        "../transactions/example-assets/example-nft/setup_collection.cdc",
        [],
        alice
    )
    Test.expect(setupCollectionResult, Test.beSucceeded())

    let mintExampleNFTResult = executeTransaction(
        "../transactions/example-assets/example-nft/mint_nft.cdc",
        [alice.address, exampleNFTTokenName, exampleNFTTokenDescription, exampleNFTTokenThumbnail, [], [], []],
        exampleNFTAccount
    )
    Test.expect(mintExampleNFTResult, Test.beSucceeded())

    let aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)

    let events = Test.eventsOfType(Type<NonFungibleToken.Deposited>())
    Test.assertEqual(1, events.length)
    let evt = events[0] as! NonFungibleToken.Deposited
    mintedNFTID = evt.id

    Test.assertEqual(aliceOwnedIDs[0], mintedNFTID)
}

access(all)
fun testMintExampleTokenSucceeds() {
    let setupVaultResult = executeTransaction(
        "../transactions/example-assets/example-token/setup_vault.cdc",
        [],
        alice
    )
    Test.expect(setupVaultResult, Test.beSucceeded())

    let mintExampleTokenResult = executeTransaction(
        "../transactions/example-assets/example-token/mint_tokens.cdc",
        [alice.address, exampleTokenMintAmount],
        exampleTokenAccount
    )
    Test.expect(mintExampleTokenResult, Test.beSucceeded())

    let aliceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(exampleTokenMintAmount, aliceBalance)

    let events = Test.eventsOfType(Type<FungibleToken.Deposited>())
    let evt = events[events.length - 1] as! FungibleToken.Deposited

    Test.assertEqual(aliceBalance, evt.amount)
}

access(all)
fun testMintERC721Succeeds() {
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)
    let erc721AddressHex = getDeployedAddressFromDeployer(name: "erc721")
    Test.assertEqual(40, erc721AddressHex.length)

    let mintERC721Result = executeTransaction(
        "../transactions/example-assets/evm-assets/safe_mint_erc721.cdc",
        [aliceCOAAddressHex, erc721ID, erc721URI, erc721AddressHex, UInt64(200_000)],
        exampleERCAccount
    )
    Test.expect(mintERC721Result, Test.beSucceeded())

    let aliceIsOwner = isOwner(of: erc721ID, ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: erc721AddressHex)
    Test.assertEqual(true, aliceIsOwner)
}

access(all)
fun testMintERC20Succeeds() {
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
fun testOnboardNFTByTypeSucceeds() {
    snapshot = getCurrentBlockHeight()
    var onboaringRequiredResult: Test.ScriptResult = executeScript(
        "../scripts/bridge/type_requires_onboarding_by_identifier.cdc",
        [exampleNFTIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding_by_identifier.cdc",
        [exampleNFTIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testOnboardTokenByTypeSucceeds() {
    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding_by_identifier.cdc",
        [exampleTokenIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding_by_identifier.cdc",
        [exampleTokenIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testBatchOnboardByTypeSucceeds() {
    Test.assert(snapshot != 0, message: "Expected snapshot to be taken before onboarding any types")
    Test.reset(to: snapshot)

    let nftOnboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding_by_identifier.cdc",
        [exampleNFTIdentifier]
    )
    Test.expect(nftOnboaringRequiredResult, Test.beSucceeded())
    let nftRequiresOnboarding = nftOnboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, nftRequiresOnboarding)
    let tokenOnboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding_by_identifier.cdc",
        [exampleTokenIdentifier]
    )
    Test.expect(tokenOnboaringRequiredResult, Test.beSucceeded())
    let tokenRequiresOnboarding = tokenOnboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, tokenRequiresOnboarding)

    let exampleNFTType = Type<@ExampleNFT.NFT>()
    let exampleTokenType = Type<@ExampleToken.Vault>()
    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/batch_onboard_by_type.cdc",
        [[exampleNFTType, exampleTokenType]],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    let expectedBatchOnboardingRequired: {Type: Bool?} = {
        exampleNFTType: false,
        exampleTokenType: false
    }
    let batchOnboaringRequiredResult = executeScript(
        "../scripts/bridge/batch_type_requires_onboarding.cdc",
        [[exampleNFTType, exampleTokenType]]
    )
    Test.expect(batchOnboaringRequiredResult, Test.beSucceeded())
    let batchRequiresOnboarding = batchOnboaringRequiredResult.returnValue as! {Type: Bool?}? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(expectedBatchOnboardingRequired, batchRequiresOnboarding)

    // Should succeed as batch onboarding skips already onboarded types
    onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/batch_onboard_by_type.cdc",
        [[exampleNFTType, exampleTokenType]],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())
}



access(all)
fun testOnboardERC721ByEVMAddressSucceeds() {
    snapshot = getCurrentBlockHeight()

    let erc721AddressHex = getDeployedAddressFromDeployer(name: "erc721")
    Test.assertEqual(40, erc721AddressHex.length)

    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc721AddressHex]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc721AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    onboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc721AddressHex]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc721AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testOnboardERC20ByEVMAddressSucceeds() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    Test.assertEqual(40, erc20AddressHex.length)

    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc20AddressHex]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc20AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    onboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc20AddressHex]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc20AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testBatchOnboardByEVMAddressSucceeds() {
    Test.assert(snapshot != 0, message: "Expected snapshot to be taken before onboarding any EVM contracts")
    Test.reset(to: snapshot)

    let erc721AddressHex = getDeployedAddressFromDeployer(name: "erc721")
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    Test.assertEqual(40, erc721AddressHex.length)
    Test.assertEqual(40, erc20AddressHex.length)

    var erc721OnboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc721AddressHex]
    )
    Test.expect(erc721OnboaringRequiredResult, Test.beSucceeded())
    var erc721RequiresOnboarding = erc721OnboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, erc721RequiresOnboarding)
    var erc20OnboaringRequiredResult = executeScript(
        "../scripts/bridge/evm_address_requires_onboarding.cdc",
        [erc20AddressHex]
    )
    Test.expect(erc20OnboaringRequiredResult, Test.beSucceeded())
    var erc20RequiresOnboarding = erc20OnboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, erc20RequiresOnboarding)

    var batchOnboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/batch_onboard_by_evm_address.cdc",
        [[erc721AddressHex, erc20AddressHex]],
        alice
    )
    Test.expect(batchOnboardingResult, Test.beSucceeded())

    let expectedBatchRequiresOnboarding: {String: Bool?} = {
        erc721AddressHex: false,
        erc20AddressHex: false
    }
    let batchOnboaringRequiredResult = executeScript(
        "../scripts/bridge/batch_evm_address_requires_onboarding.cdc",
        [[erc721AddressHex, erc20AddressHex]]
    )
    Test.expect(batchOnboaringRequiredResult, Test.beSucceeded())
    let batchRequiresOnboarding = batchOnboaringRequiredResult.returnValue as! {String: Bool?}? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(expectedBatchRequiresOnboarding, batchRequiresOnboarding)

    // Batch onboarding should succeed as it skips already onboarded contracts
    batchOnboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/batch_onboard_by_evm_address.cdc",
        [[erc721AddressHex, erc20AddressHex]],
        alice
    )
    Test.expect(batchOnboardingResult, Test.beSucceeded())

}

/* --- BRIDGING NFTS - Test bridging both Cadence- & EVM-native NFTs --- */

access(all)
fun testBridgeCadenceNativeNFTToEVMSucceeds() {
    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    // Execute bridge to EVM
    bridgeNFTToEVM(
        signer: alice,
        contractAddr: exampleNFTAccount.address,
        contractName: "ExampleNFT",
        nftID: aliceOwnedIDs[0],
        bridgeAccountAddr: bridgeAccount.address
    )

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Confirm the NFT is no longer in Alice's Collection
    aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(0, aliceOwnedIDs.length)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    let isOwnerResult = executeScript(
        "../scripts/utils/is_owner.cdc",
        [UInt256(mintedNFTID), aliceCOAAddressHex, associatedEVMAddressHex]
    )
    Test.expect(isOwnerResult, Test.beSucceeded())
    Test.assertEqual(true, isOwnerResult.returnValue as! Bool? ?? panic("Problem getting owner status"))
}

access(all)
fun testBridgeCadenceNativeNFTFromEVMSucceeds() {
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Assert ownership of the bridged NFT in EVM
    var aliceIsOwner = isOwner(of: UInt256(mintedNFTID), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)

    // Execute bridge from EVM
    bridgeNFTFromEVM(
        signer: alice,
        contractAddr: exampleNFTAccount.address,
        contractName: "ExampleNFT",
        erc721ID: UInt256(mintedNFTID),
        bridgeAccountAddr: bridgeAccount.address
    )

    // Assert ownership of the bridged NFT in EVM has transferred
    aliceIsOwner = isOwner(of: UInt256(mintedNFTID), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(false, aliceIsOwner)

    // Assert the NFT is back in Alice's Collection
    let aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)
    Test.assertEqual(mintedNFTID, aliceOwnedIDs[0])
}

access(all)
fun testBridgeEVMNativeNFTFromEVMSucceeds() {
    let erc721AddressHex = getDeployedAddressFromDeployer(name: "erc721")
    Test.assertEqual(40, erc721AddressHex.length)

    let derivedERC721ContractName = deriveBridgedNFTContractName(evmAddressHex: erc721AddressHex)
    let bridgedCollectionPathIdentifier = derivedERC721ContractName.concat("Collection")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    bridgeNFTFromEVM(
        signer: alice,
        contractAddr: bridgeAccount.address,
        contractName: derivedERC721ContractName,
        erc721ID: erc721ID,
        bridgeAccountAddr: bridgeAccount.address
    )

    let aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: bridgedCollectionPathIdentifier)
    Test.assertEqual(1, aliceOwnedIDs.length)

    let evmIDResult = executeScript(
        "../scripts/nft/get_evm_id_from_evm_nft.cdc",
        [alice.address, aliceOwnedIDs[0], StoragePath(identifier: bridgedCollectionPathIdentifier)!]
    )
    Test.expect(evmIDResult, Test.beSucceeded())
    let evmID = evmIDResult.returnValue as! UInt256? ?? panic("Problem getting EVM ID")
    Test.assertEqual(erc721ID, evmID)
}

access(all)
fun testBridgeEVMNativeNFTToEVMSucceeds() {
    let erc721AddressHex = getDeployedAddressFromDeployer(name: "erc721")
    Test.assertEqual(40, erc721AddressHex.length)

    let derivedERC721ContractName = deriveBridgedNFTContractName(evmAddressHex: erc721AddressHex)
    let bridgedCollectionPathIdentifier = derivedERC721ContractName.concat("Collection")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: bridgedCollectionPathIdentifier)
    Test.assertEqual(1, aliceOwnedIDs.length)

    bridgeNFTToEVM(
        signer: alice,
        contractAddr: bridgeAccount.address,
        contractName: derivedERC721ContractName,
        nftID: aliceOwnedIDs[0],
        bridgeAccountAddr: bridgeAccount.address
    )

    aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: bridgedCollectionPathIdentifier)
    Test.assertEqual(0, aliceOwnedIDs.length)

    let aliceIsOwner = isOwner(of: erc721ID, ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: erc721AddressHex)
    Test.assertEqual(true, aliceIsOwner)
}

/* --- BRIDGING FUNGIBLE TOKENS - Test bridging both Cadence- & EVM-native fungible tokens --- */

access(all)
fun testBridgeCadenceNativeTokenToEVMSucceeds() {
    var cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assert(cadenceBalance == exampleTokenMintAmount)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    // Execute bridge to EVM
    bridgeTokensToEVM(
        signer: alice,
        contractAddr: exampleTokenAccount.address,
        contractName: "ExampleToken",
        amount: cadenceBalance
    )

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleTokenIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Confirm Alice's token balance is now 0.0
    cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(0.0, cadenceBalance)

    // Confirm balance on EVM side has been updated
    let decimals = getTokenDecimals(erc20AddressHex: associatedEVMAddressHex)
    let expectedEVMBalance = ufix64ToUInt256(exampleTokenMintAmount, decimals: decimals)
    let evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: associatedEVMAddressHex)
    Test.assertEqual(expectedEVMBalance, evmBalance)
}

access(all)
fun testBridgeCadenceNativeTokenFromEVMSucceeds() {
    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleTokenIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)
    
    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    // Confirm Alice is starting with 0.0 balance in their Cadence Vault
    var cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(0.0, cadenceBalance)

    // Get Alice's ERC20 balance & convert to UFix64
    var evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: associatedEVMAddressHex)
    let decimals = getTokenDecimals(erc20AddressHex: associatedEVMAddressHex)
    let ufixValue = uint256ToUFix64(evmBalance, decimals: decimals)
    // Assert the converted balance is equal to the originally minted amount that was bridged in the previous step
    Test.assertEqual(exampleTokenMintAmount, ufixValue)

    // Execute bridge from EVM
    bridgeTokensFromEVM(
        signer: alice,
        contractAddr: exampleTokenAccount.address,
        contractName: "ExampleToken",
        amount: evmBalance
    )

    // Confirm ExampleToken balance has been bridged back to Alice's Cadence vault
    cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(ufixValue, cadenceBalance)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: associatedEVMAddressHex)
    Test.assertEqual(UInt256(0), evmBalance)
}

access(all)
fun testBridgeEVMNativeTokenFromEVMSucceeds() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    Test.assertEqual(40, erc20AddressHex.length)

    let derivedERC20ContractName = deriveBridgedTokenContractName(evmAddressHex: erc20AddressHex)
    let bridgedVaultPathIdentifier = derivedERC20ContractName.concat("Vault")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    var evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, evmBalance)

    // Confirm Alice does not yet have a bridged Vault configured
    var cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: bridgedVaultPathIdentifier)
    Test.assertEqual(nil, cadenceBalance)

    // Execute bridge from EVM
    bridgeTokensFromEVM(
        signer: alice,
        contractAddr: bridgeAccount.address,
        contractName: derivedERC20ContractName,
        amount: evmBalance
    )

    // Confirm EVM balance is no 0
    evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(UInt256(0), evmBalance)

    // Confirm the Cadence Vault is now configured and contains the bridged balance
    cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: bridgedVaultPathIdentifier)
        ?? panic("Bridged token Vault was not found in Alice's account after bridging")
    let decimals = getTokenDecimals(erc20AddressHex: erc20AddressHex)
    let expectedCadenceBalance = uint256ToUFix64(erc20MintAmount, decimals: decimals)
    Test.assertEqual(expectedCadenceBalance, cadenceBalance!)

    // With the bridge executed, confirm the bridge COA escrows the ERC20 tokens
    let bridgeCOAAddressHex = getCOAAddressHex(atFlowAddress: bridgeAccount.address)
    Test.assertEqual(40, bridgeCOAAddressHex.length)
    let bridgeCOAEscrowBalance = balanceOf(evmAddressHex: bridgeCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, bridgeCOAEscrowBalance)
}

access(all)
fun testBridgeEVMNativeTokenToEVMSucceeds() {
    let erc20AddressHex = getDeployedAddressFromDeployer(name: "erc20")
    Test.assertEqual(40, erc20AddressHex.length)

    let derivedERC20ContractName = deriveBridgedTokenContractName(evmAddressHex: erc20AddressHex)
    let bridgedVaultPathIdentifier = derivedERC20ContractName.concat("Vault")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    // Confirm Cadence Vault has the expected balance
    var cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: bridgedVaultPathIdentifier)
        ?? panic("Bridged token Vault was not found in Alice's account after bridging")
    let decimals = getTokenDecimals(erc20AddressHex: erc20AddressHex)
    let expectedCadenceBalance = uint256ToUFix64(erc20MintAmount, decimals: decimals)
    Test.assertEqual(expectedCadenceBalance, cadenceBalance)

    // Confirm EVM balance is 0
    var evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(UInt256(0), evmBalance)

    // Confirm the bridge COA currently escrows the ERC20 tokens we will be bridging
    let bridgeCOAAddressHex = getCOAAddressHex(atFlowAddress: bridgeAccount.address)
    Test.assertEqual(40, bridgeCOAAddressHex.length)
    var bridgeCOAEscrowBalance = balanceOf(evmAddressHex: bridgeCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, bridgeCOAEscrowBalance)

    // Execute bridge from EVM
    bridgeTokensToEVM(
        signer: alice,
        contractAddr: bridgeAccount.address,
        contractName: derivedERC20ContractName,
        amount: cadenceBalance
    )

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, evmBalance)

    cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: bridgedVaultPathIdentifier)
        ?? panic("Bridged token Vault was not found in Alice's account after bridging")
    Test.assertEqual(0.0, cadenceBalance)

    // Confirm the bridge COA no longer escrows the ERC20 tokens
    bridgeCOAEscrowBalance = balanceOf(evmAddressHex: bridgeCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(UInt256(0), bridgeCOAEscrowBalance)
}
