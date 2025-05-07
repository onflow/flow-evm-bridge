import Test
import BlockchainHelpers

import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "FungibleTokenMetadataViews"
import "ExampleNFT"
import "ExampleToken"
import "FlowStorageFees"
import "EVM"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let exampleERCAccount = Test.getAccount(0x0000000000000009)
access(all) let exampleTokenAccount = Test.getAccount(0x0000000000000010)
access(all) let alice = Test.createAccount()
access(all) let bob = Test.createAccount()

// ExampleNFT values
access(all) let exampleNFTIdentifier = "A.0000000000000008.ExampleNFT.NFT"
access(all) let exampleNFTTokenName = "Example NFT"
access(all) let exampleNFTTokenDescription = "Example NFT token description"
access(all) let exampleNFTTokenThumbnail = "https://examplenft.com/thumbnail.png"
access(all) var mintedNFTID1: UInt64 = 0
access(all) var mintedNFTID2: UInt64 = 0

// ExampleToken
access(all) let exampleTokenIdentifier = "A.0000000000000010.ExampleToken.Vault"
access(all) let exampleTokenMintAmount = 100.0

// Bridge-related EVM contract values
access(all) var registryAddressHex: String = ""
access(all) var erc20DeployerAddressHex: String = ""
access(all) var erc721DeployerAddressHex: String = ""

// ERC721 values
access(all) var erc721AddressHex: String = ""
access(all) let erc721Name = "NAME"
access(all) let erc721Symbol = "SYMBOL"
access(all) let erc721ID: UInt256 = 42
access(all) let erc721URI = "URI"

// ERC20 values
access(all) var erc20AddressHex: String = ""
access(all) let erc20MintAmount: UInt256 = 100_000_000_000_000_000_000 // 100.0 as uint256 (100e18)

// Fee initialiazation values
access(all) let expectedOnboardFee = 1.0
access(all) let expectedBaseFee = 0.001

// Test height snapshot for test state resets
access(all) var snapshot: UInt64 = 0

access(all)
fun setup() {
    setupBridge(bridgeAccount: bridgeAccount, serviceAccount: serviceAccount, unpause: false)

    // Configure example ERC20 account with a COA
    transferFlow(signer: serviceAccount, recipient: exampleERCAccount.address, amount: 1_000.0)
    createCOA(signer: exampleERCAccount, fundingAmount: 10.0)

    // err = Test.deployContract(
    var err = Test.deployContract(
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

/* --- CONFIG TEST --- */

access(all)
fun testUnpauseBridgeSucceeds() {
    updateBridgePauseStatus(signer: bridgeAccount, pause: false)
}

access(all)
fun testSetGasLimitSucceeds() {

    fun getGasLimit(): UInt64 {
        let gasLimitResult = executeScript(
            "../scripts/bridge/get_gas_limit.cdc",
            []
        )
        Test.expect(gasLimitResult, Test.beSucceeded())
        return gasLimitResult.returnValue as! UInt64? ?? panic("Problem getting gas limit")
    }

    snapshot = getCurrentBlockHeight()

    let preGasLimit = getGasLimit()
    let gasLimit = preGasLimit + 1_000

    let setGasLimitResult = executeTransaction(
        "../transactions/bridge/admin/gas/set_gas_limit.cdc",
        [gasLimit],
        bridgeAccount
    )
    Test.expect(setGasLimitResult, Test.beSucceeded())

    let postGasLimit = getGasLimit()
    Test.assertEqual(gasLimit, postGasLimit)

    Test.reset(to: snapshot)
}

/* --- ASSET & ACCOUNT SETUP - Configure test accounts with assets to bridge --- */

access(all)
fun testDeployERC721Succeeds() {
    let erc721DeployResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getCompiledERC721Bytecode(), UInt64(15_000_000), 0.0],
        exampleERCAccount
    )
    Test.expect(erc721DeployResult, Test.beSucceeded())

    // Get ERC721 & ERC20 deployed contract addresses
    let evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    Test.assertEqual(21, evts.length)
    erc721AddressHex = getEVMAddressHexFromEvents(evts, idx: 20)
}

access(all)
fun testDeployERC20Succeeds() {
    let erc20DeployResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getCompiledERC20Bytecode(), UInt64(15_000_000), 0.0],
        exampleERCAccount
    )
    Test.expect(erc20DeployResult, Test.beSucceeded())

    // Get ERC721 & ERC20 deployed contract addresses
    let evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    Test.assertEqual(22, evts.length)
    erc20AddressHex = getEVMAddressHexFromEvents(evts, idx: 21)

}

access(all)
fun testCreateCOASucceeds() {
    transferFlow(signer: serviceAccount, recipient: alice.address, amount: 1_000.0)
    transferFlow(signer: serviceAccount, recipient: bob.address, amount: 1_000.0)
    createCOA(signer: alice, fundingAmount: 100.0)
    createCOA(signer: bob, fundingAmount: 100.0)

    let aliceCOAAddress = getCOAAddressHex(atFlowAddress: alice.address)
    let bobCOAAddress = getCOAAddressHex(atFlowAddress: bob.address)
}

access(all)
fun testMintExampleNFTSucceeds() {
    let setupCollectionResult = executeTransaction(
        "../transactions/example-assets/example-nft/setup_collection.cdc",
        [],
        alice
    )
    Test.expect(setupCollectionResult, Test.beSucceeded())
    let hasCollection = executeScript(
        "../scripts/nft/has_collection_configured.cdc",
        [exampleNFTIdentifier, alice.address]
    )
    Test.expect(hasCollection, Test.beSucceeded())
    Test.assertEqual(true, hasCollection.returnValue as! Bool? ?? panic("Problem getting collection status"))

    var mintExampleNFTResult = executeTransaction(
        "../transactions/example-assets/example-nft/mint_nft.cdc",
        [alice.address, exampleNFTTokenName, exampleNFTTokenDescription, exampleNFTTokenThumbnail, [], [], []],
        exampleNFTAccount
    )
    Test.expect(mintExampleNFTResult, Test.beSucceeded())

    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)

    var events = Test.eventsOfType(Type<NonFungibleToken.Deposited>())
    Test.assertEqual(1, events.length)
    var evt = events[0] as! NonFungibleToken.Deposited
    mintedNFTID1 = evt.id

    mintExampleNFTResult = executeTransaction(
        "../transactions/example-assets/example-nft/mint_nft.cdc",
        [alice.address, exampleNFTTokenName, exampleNFTTokenDescription, exampleNFTTokenThumbnail, [], [], []],
        exampleNFTAccount
    )
    Test.expect(mintExampleNFTResult, Test.beSucceeded())

    aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(2, aliceOwnedIDs.length)

    events = Test.eventsOfType(Type<NonFungibleToken.Deposited>())
    Test.assertEqual(2, events.length)
    evt = events[1] as! NonFungibleToken.Deposited
    mintedNFTID2 = evt.id

    Test.assert(mintedNFTID1 != mintedNFTID2)
    Test.assertEqual(true, aliceOwnedIDs.contains(mintedNFTID1) && aliceOwnedIDs.contains(mintedNFTID2))
}

access(all)
fun testMintExampleTokenSucceeds() {
    let setupVaultResult = executeTransaction(
        "../transactions/example-assets/example-token/setup_vault.cdc",
        [],
        alice
    )
    Test.expect(setupVaultResult, Test.beSucceeded())
    let hasVault = executeScript(
        "../scripts/tokens/has_vault_configured.cdc",
        [exampleTokenIdentifier, alice.address]
    )
    Test.expect(hasVault, Test.beSucceeded())
    Test.assertEqual(true, hasVault.returnValue as! Bool? ?? panic("Problem getting vault status"))

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
    fun getFee(feeType: String): UFix64 {
        let feeResult = executeScript(
            "../scripts/config/get_".concat(feeType).concat(".cdc"),
            []
        )
        Test.expect(feeResult, Test.beSucceeded())
        return feeResult.returnValue as! UFix64? ?? panic("Problem getting fee: ".concat(feeType))
    }

    fun calculateBridgeFee(bytesUsed: UInt64): UFix64 {
        let calculatedResult = executeScript(
            "../scripts/bridge/calculate_bridge_fee.cdc",
            [bytesUsed]
        )
        Test.expect(calculatedResult, Test.beSucceeded())
        return calculatedResult.returnValue as! UFix64? ?? panic("Problem getting calculated fee")
    }

    let bytesUsed: UInt64 = 1024
    let expectedFinalFee = FlowStorageFees.storageCapacityToFlow(
            FlowStorageFees.convertUInt64StorageBytesToUFix64Megabytes(bytesUsed)
        ) + expectedBaseFee

    // Validate the initialized values are set to 0.0
    var actualOnboardFee = getFee(feeType: "onboard_fee")
    var actualBaseFee = getFee(feeType: "base_fee")

    Test.assertEqual(0.0, actualOnboardFee)
    Test.assertEqual(0.0, actualBaseFee)

    var actualCalculated = calculateBridgeFee(bytesUsed: bytesUsed)
    Test.assertEqual(0.0, actualCalculated)

    // Set the fees to new values
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

    // Validate the values have been updated
    actualOnboardFee = getFee(feeType: "onboard_fee")
    actualBaseFee = getFee(feeType: "base_fee")

    Test.assertEqual(expectedOnboardFee, actualOnboardFee)
    Test.assertEqual(expectedBaseFee, actualBaseFee)

    actualCalculated = calculateBridgeFee(bytesUsed: bytesUsed)
    Test.assertEqual(expectedFinalFee, actualCalculated)
}

/* --- ONBOARDING - Test asset onboarding to the bridge --- */

access(all)
fun testOnboardNFTByTypeSucceeds() {
    snapshot = getCurrentBlockHeight()

    var requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, requiresOnboarding)

    onboardByTypeIdentifier(signer: alice, typeIdentifier: exampleNFTIdentifier, beFailed: false)

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    onboardByTypeIdentifier(signer: alice, typeIdentifier: exampleNFTIdentifier, beFailed: true)
}

access(all)
fun testOnboardAndBridgeNFTToEVMSucceeds() {
    // Revert to state before ExampleNFT was onboarded
    Test.reset(to: snapshot)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(2, aliceOwnedIDs.length)

    var requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, requiresOnboarding)

    // Execute bridge NFT to EVM - should also onboard the NFT type
    bridgeNFTToEVM(
        signer: alice,
        nftIdentifier: exampleNFTIdentifier,
        nftID: mintedNFTID1,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    onboardByTypeIdentifier(signer: alice, typeIdentifier: exampleNFTIdentifier, beFailed: true)

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Confirm the NFT is no longer in Alice's Collection
    aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    let aliceIsOwner = isOwner(of: UInt256(mintedNFTID1), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)
}

access(all)
fun testOnboardAndCrossVMTransferNFTToEVMSucceeds() {
    // Revert to state before ExampleNFT was onboarded
    Test.reset(to: snapshot)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(2, aliceOwnedIDs.length)

    let recipient = getCOAAddressHex(atFlowAddress: bob.address)

    var requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, requiresOnboarding)

    // Execute bridge NFT to EVM recipient - should also onboard the NFT type
    let crossVMTransferResult = executeTransaction(
        "../transactions/bridge/nft/bridge_nft_to_any_evm_address.cdc",
        [ exampleNFTIdentifier, mintedNFTID1, recipient ],
        alice
    )
    Test.expect(crossVMTransferResult, Test.beSucceeded())

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    onboardByTypeIdentifier(signer: alice, typeIdentifier: exampleNFTIdentifier, beFailed: true)

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Confirm the NFT is no longer in Alice's Collection
    aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    var aliceIsOwner = isOwner(of: UInt256(mintedNFTID1), ownerEVMAddrHex: recipient, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)
}

access(all)
fun testOnboardTokenByTypeSucceeds() {
    var requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleTokenIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, requiresOnboarding)

    onboardByTypeIdentifier(signer: alice, typeIdentifier: exampleTokenIdentifier, beFailed: false)

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleTokenIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    onboardByTypeIdentifier(signer: alice, typeIdentifier: exampleTokenIdentifier, beFailed: true)
}

access(all)
fun testOnboardAndBridgeTokensToEVMSucceeds() {
    // Revert to state before ExampleNFT was onboarded
    Test.reset(to: snapshot)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    var cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Could not get ExampleToken balance")

    var requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleTokenIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, requiresOnboarding)

    // Execute bridge to EVM - should also onboard the token type
    bridgeTokensToEVM(
        signer: alice,
        vaultIdentifier: exampleTokenIdentifier,
        amount: cadenceBalance,
        beFailed: false
    )

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleTokenIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    onboardByTypeIdentifier(signer: alice, typeIdentifier: exampleTokenIdentifier, beFailed: true)

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
fun testOnboardAndCrossVMTransferTokensToEVMSucceeds() {
    // Revert to state before ExampleNFT was onboarded
    Test.reset(to: snapshot)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    var cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Could not get ExampleToken balance")
    let recipient = getCOAAddressHex(atFlowAddress: bob.address)

    var requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleTokenIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, requiresOnboarding)

    // Execute bridge to EVM - should also onboard the token type
    let crossVMTransferResult = executeTransaction(
        "../transactions/bridge/tokens/bridge_tokens_to_any_evm_address.cdc",
        [ exampleTokenIdentifier, cadenceBalance, recipient ],
        alice
    )
    Test.expect(crossVMTransferResult, Test.beSucceeded())

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleTokenIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    onboardByTypeIdentifier(signer: alice, typeIdentifier: exampleTokenIdentifier, beFailed: true)

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleTokenIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Confirm Alice's token balance is now 0.0
    cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(0.0, cadenceBalance)

    // Confirm balance on EVM side has been updated
    let decimals = getTokenDecimals(erc20AddressHex: associatedEVMAddressHex)
    let expectedEVMBalance = ufix64ToUInt256(exampleTokenMintAmount, decimals: decimals)
    let evmBalance = balanceOf(evmAddressHex: recipient, erc20AddressHex: associatedEVMAddressHex)
    Test.assertEqual(expectedEVMBalance, evmBalance)
}

access(all)
fun testBatchOnboardByTypeSucceeds() {
    Test.assert(snapshot != 0, message: "Expected snapshot to be taken before onboarding any types")
    Test.reset(to: snapshot)

    let nftRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, nftRequiresOnboarding)
    let tokenRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleTokenIdentifier)
        ?? panic("Problem getting onboarding status for type")
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
    let batchOnboardingRequiredResult = executeScript(
        "../scripts/bridge/batch_type_requires_onboarding.cdc",
        [[exampleNFTType, exampleTokenType]]
    )
    Test.expect(batchOnboardingRequiredResult, Test.beSucceeded())
    let batchRequiresOnboarding = batchOnboardingRequiredResult.returnValue as! {Type: Bool?}? ?? panic("Problem getting onboarding requirement")
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

    // Validate EVMBlocklist works by blocking the EVM address
    let blockResult = executeTransaction(
        "../transactions/bridge/admin/blocklist/block_evm_address.cdc",
        [erc721AddressHex],
        bridgeAccount
    )
    Test.expect(blockResult, Test.beSucceeded())

    // onboarding should fail as the EVM address is blocked
    onboardByEVMAddress(signer: alice, evmAddressHex: erc721AddressHex, beFailed: true)

    // Unblock the EVM address
    let unblockResult = executeTransaction(
        "../transactions/bridge/admin/blocklist/unblock_evm_address.cdc",
        [erc721AddressHex],
        bridgeAccount
    )
    Test.expect(unblockResult, Test.beSucceeded())

    // And now onboarding should succeed

    var requiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    onboardByEVMAddress(signer: alice, evmAddressHex: erc721AddressHex, beFailed: false)

    requiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    onboardByEVMAddress(signer: alice, evmAddressHex: erc721AddressHex, beFailed: true)
}

access(all)
fun testOnboardERC20ByEVMAddressSucceeds() {

    var requiresOnboarding = evmAddressRequiresOnboarding(erc20AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    onboardByEVMAddress(signer: alice, evmAddressHex: erc20AddressHex, beFailed: false)

    requiresOnboarding = evmAddressRequiresOnboarding(erc20AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    onboardByEVMAddress(signer: alice, evmAddressHex: erc20AddressHex, beFailed: true)
}

access(all)
fun testBatchOnboardByEVMAddressSucceeds() {
    Test.assert(snapshot != 0, message: "Expected snapshot to be taken before onboarding any EVM contracts")
    Test.reset(to: snapshot)

    var erc721RequiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    var erc20RequiresOnboarding = evmAddressRequiresOnboarding(erc20AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, erc721RequiresOnboarding)
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
    let batchOnboardingRequiredResult = executeScript(
        "../scripts/bridge/batch_evm_address_requires_onboarding.cdc",
        [[erc721AddressHex, erc20AddressHex]]
    )
    Test.expect(batchOnboardingRequiredResult, Test.beSucceeded())
    let batchRequiresOnboarding = batchOnboardingRequiredResult.returnValue as! {String: Bool?}? ?? panic("Problem getting onboarding requirement")
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
fun testPauseBridgeSucceeds() {
    // Pause the bridge
    updateBridgePauseStatus(signer: bridgeAccount, pause: true)

    var isPausedResult = executeScript(
        "../scripts/bridge/is_paused.cdc",
        []
    )
    Test.expect(isPausedResult, Test.beSucceeded())
    Test.assertEqual(true, isPausedResult.returnValue as! Bool? ?? panic("Problem getting pause status"))

    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(2, aliceOwnedIDs.length)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Execute bridge to EVM - should fail after pausing
    bridgeNFTToEVM(
        signer: alice,
        nftIdentifier: exampleNFTIdentifier,
        nftID: aliceOwnedIDs[0],
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: true
    )

    // Unpause bridging
    updateBridgePauseStatus(signer: bridgeAccount, pause: false)

    isPausedResult = executeScript(
        "../scripts/bridge/is_paused.cdc",
        []
    )
    Test.expect(isPausedResult, Test.beSucceeded())
    Test.assertEqual(false, isPausedResult.returnValue as! Bool? ?? panic("Problem getting pause status"))
}

access(all)
fun testBridgeCadenceNativeNFTToEVMSucceeds() {
    snapshot = getCurrentBlockHeight()

    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(2, aliceOwnedIDs.length)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Execute bridge to EVM
    bridgeNFTToEVM(
        signer: alice,
        nftIdentifier: exampleNFTIdentifier,
        nftID: mintedNFTID1,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Confirm the NFT is no longer in Alice's Collection
    aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    let isOwnerResult = executeScript(
        "../scripts/utils/is_owner.cdc",
        [UInt256(mintedNFTID1), aliceCOAAddressHex, associatedEVMAddressHex]
    )
    Test.expect(isOwnerResult, Test.beSucceeded())
    Test.assertEqual(true, isOwnerResult.returnValue as! Bool? ?? panic("Problem getting owner status"))

    let isNFTLocked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: mintedNFTID1)
    Test.assertEqual(true, isNFTLocked)

    let metadata = resolveLockedNFTView(bridgeAddress: bridgeAccount.address, nftTypeIdentifier: exampleNFTIdentifier, id: UInt256(mintedNFTID1), viewIdentifier: Type<MetadataViews.Display>().identifier)
    Test.assert(metadata != nil, message: "Expected NFT metadata to be resolved from escrow but none was returned")
}

access(all)
fun testBatchBridgeCadenceNativeNFTToEVMSucceeds() {
    let tmp = snapshot
    Test.reset(to: snapshot)
    snapshot = tmp

    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(2, aliceOwnedIDs.length)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Execute bridge to EVM
    let bridgeResult = executeTransaction(
        "../transactions/bridge/nft/batch_bridge_nft_to_evm.cdc",
        [ exampleNFTIdentifier, aliceOwnedIDs ],
        alice
    )
    Test.expect(bridgeResult, Test.beSucceeded())

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Confirm the NFT is no longer in Alice's Collection
    aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(0, aliceOwnedIDs.length)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    var aliceIsOwner = isOwner(of: UInt256(mintedNFTID1), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)
    aliceIsOwner = isOwner(of: UInt256(mintedNFTID2), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)

    let isNFT1Locked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: mintedNFTID1)
    let isNFT2Locked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: mintedNFTID2)
    Test.assertEqual(true, isNFT1Locked)
    Test.assertEqual(true, isNFT2Locked)

    let metadata1 = resolveLockedNFTView(bridgeAddress: bridgeAccount.address, nftTypeIdentifier: exampleNFTIdentifier, id: UInt256(mintedNFTID1), viewIdentifier: Type<MetadataViews.Display>().identifier)
    let metadata2 = resolveLockedNFTView(bridgeAddress: bridgeAccount.address, nftTypeIdentifier: exampleNFTIdentifier, id: UInt256(mintedNFTID2), viewIdentifier: Type<MetadataViews.Display>().identifier)
    Test.assert(metadata1 != nil, message: "Expected NFT metadata to be resolved from escrow but none was returned")
    Test.assert(metadata2 != nil, message: "Expected NFT metadata to be resolved from escrow but none was returned")
}

access(all)
fun testBatchBridgeCadenceNativeNFTFromEVMSucceeds() {
    snapshot = getCurrentBlockHeight()

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)
    
    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    var aliceIsOwner = isOwner(of: UInt256(mintedNFTID1), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)
    aliceIsOwner = isOwner(of: UInt256(mintedNFTID2), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)

    // Execute bridge from EVM
    let bridgeResult = executeTransaction(
        "../transactions/bridge/nft/batch_bridge_nft_from_evm.cdc",
        [ exampleNFTIdentifier, [UInt256(mintedNFTID1), UInt256(mintedNFTID2)] ],
        alice
    )
    Test.expect(bridgeResult, Test.beSucceeded())

    // Confirm the NFT is no longer in Alice's Collection
    let aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(2, aliceOwnedIDs.length)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    aliceIsOwner = isOwner(of: UInt256(mintedNFTID1), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(false, aliceIsOwner)
    aliceIsOwner = isOwner(of: UInt256(mintedNFTID2), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(false, aliceIsOwner)

    let isNFT1Locked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: mintedNFTID1)
    let isNFT2Locked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: mintedNFTID2)
    Test.assertEqual(false, isNFT1Locked)
    Test.assertEqual(false, isNFT2Locked)
}

access(all)
fun testCrossVMTransferCadenceNativeNFTFromEVMSucceeds() {
    let tmp = snapshot
    Test.reset(to: snapshot)
    snapshot = getCurrentBlockHeight()

    // Configure recipient's Collection first, using generic setup transaction
    let setupCollectionResult = executeTransaction(
        "../transactions/example-assets/setup/setup_generic_nft_collection.cdc",
        [exampleNFTIdentifier],
        bob
    )
    Test.expect(setupCollectionResult, Test.beSucceeded())

    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Assert ownership of the bridged NFT in EVM
    var aliceIsOwner = isOwner(of: UInt256(mintedNFTID1), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)

    // Execute bridge NFT from EVM to Cadence recipient (Bob in this case)
    let crossVMTransferResult = executeTransaction(
        "../transactions/bridge/nft/bridge_nft_to_any_cadence_address.cdc",
        [ exampleNFTIdentifier, UInt256(mintedNFTID1), bob.address ],
        alice
    )
    Test.expect(crossVMTransferResult, Test.beSucceeded())

    // Assert ownership of the bridged NFT in EVM has transferred
    aliceIsOwner = isOwner(of: UInt256(mintedNFTID1), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(false, aliceIsOwner)

    // Assert the NFT is now in Bob's Collection
    let bobOwnedIDs = getIDs(ownerAddr: bob.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, bobOwnedIDs.length)
    Test.assertEqual(mintedNFTID1, bobOwnedIDs[0])

    let isNFTLocked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: mintedNFTID1)
    Test.assertEqual(false, isNFTLocked)
}

access(all)
fun testBridgeCadenceNativeNFTFromEVMSucceeds() {
    Test.reset(to: snapshot)
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Assert ownership of the bridged NFT in EVM
    var aliceIsOwner = isOwner(of: UInt256(mintedNFTID1), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)

    // Execute bridge from EVM
    bridgeNFTFromEVM(
        signer: alice,
        nftIdentifier: exampleNFTIdentifier,
        erc721ID: UInt256(mintedNFTID1),
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )

    // Assert ownership of the bridged NFT in EVM has transferred
    aliceIsOwner = isOwner(of: UInt256(mintedNFTID1), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(false, aliceIsOwner)

    // Assert the NFT is back in Alice's Collection
    let aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)
    Test.assertEqual(true, aliceOwnedIDs.contains(mintedNFTID1))
}

access(all)
fun testBridgeEVMNativeNFTFromEVMSucceeds() {

    let derivedERC721ContractName = deriveBridgedNFTContractName(evmAddressHex: erc721AddressHex)
    let bridgedCollectionPathIdentifier = derivedERC721ContractName.concat("Collection")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    bridgeNFTFromEVM(
        signer: alice,
        nftIdentifier: buildTypeIdentifier(
            address: bridgeAccount.address,
            contractName: derivedERC721ContractName,
            resourceName: "NFT"
        ), erc721ID: erc721ID,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
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

    let viewsResolved = executeScript(
        "./scripts/resolve_bridged_nft_views.cdc",
        [alice.address, bridgedCollectionPathIdentifier, aliceOwnedIDs[0]]
    )
    Test.expect(viewsResolved, Test.beSucceeded())
    Test.assertEqual(true, viewsResolved.returnValue as! Bool? ?? panic("Problem resolving views"))
}


access(all)
fun testPauseByTypeSucceeds() {
    // Pause the bridge
    let pauseResult = executeTransaction(
        "../transactions/bridge/admin/pause/update_type_pause_status.cdc",
        [exampleNFTIdentifier, true],
        bridgeAccount
    )
    Test.expect(pauseResult, Test.beSucceeded())
    var isPausedResult = executeScript(
        "../scripts/bridge/is_type_paused.cdc",
        [exampleNFTIdentifier]
    )
    Test.expect(isPausedResult, Test.beSucceeded())
    Test.assertEqual(true, isPausedResult.returnValue as! Bool? ?? panic("Problem getting pause status"))

    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Execute bridge to EVM - should fail after pausing
    bridgeNFTToEVM(
        signer: alice,
        nftIdentifier: exampleNFTIdentifier,
        nftID: mintedNFTID1,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: true
    )

    // Unpause bridging
    let unpauseResult = executeTransaction(
        "../transactions/bridge/admin/pause/update_type_pause_status.cdc",
        [exampleNFTIdentifier, false],
        bridgeAccount
    )
    Test.expect(unpauseResult, Test.beSucceeded())

    isPausedResult = executeScript(
        "../scripts/bridge/is_type_paused.cdc",
        [exampleNFTIdentifier]
    )
    Test.expect(isPausedResult, Test.beSucceeded())
    Test.assertEqual(false, isPausedResult.returnValue as! Bool? ?? panic("Problem getting pause status"))
}

access(all)
fun testBridgeEVMNativeNFTToEVMSucceeds() {

    let derivedERC721ContractName = deriveBridgedNFTContractName(evmAddressHex: erc721AddressHex)
    let bridgedCollectionPathIdentifier = derivedERC721ContractName.concat("Collection")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: bridgedCollectionPathIdentifier)
    Test.assertEqual(1, aliceOwnedIDs.length)

    bridgeNFTToEVM(
        signer: alice,
        nftIdentifier: buildTypeIdentifier(
            address: bridgeAccount.address,
            contractName: derivedERC721ContractName,
            resourceName: "NFT"
        ), nftID: aliceOwnedIDs[0],
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
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

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleTokenIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    let decimals = getTokenDecimals(erc20AddressHex: associatedEVMAddressHex)
    let expectedTotalBalance = ufix64ToUInt256(exampleTokenMintAmount, decimals: decimals)

    var completeBalances = getFullBalance(ownerAddr: alice.address, vaultIdentifier: exampleTokenIdentifier, erc20AddressHex: nil)
    Test.assert(completeBalances[0] == expectedTotalBalance)
    Test.assert(completeBalances[1] == 0)
    Test.assert(completeBalances[2] == expectedTotalBalance)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Execute bridge to EVM
    bridgeTokensToEVM(
        signer: alice,
        vaultIdentifier: exampleTokenIdentifier,
        amount: cadenceBalance,
        beFailed: false
    )

    // Confirm Alice's token balance is now 0.0
    cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(0.0, cadenceBalance)

    // Confirm balance on EVM side has been updated
    let evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: associatedEVMAddressHex)
    Test.assertEqual(expectedTotalBalance, evmBalance)

    // Confirm the token is locked
    let lockedBalance = getLockedTokenBalance(vaultTypeIdentifier: exampleTokenIdentifier) ?? panic("Problem getting locked balance")
    Test.assertEqual(exampleTokenMintAmount, lockedBalance)

    let metadata = resolveLockedTokenView(bridgeAddress: bridgeAccount.address, vaultTypeIdentifier: exampleTokenIdentifier, viewIdentifier: Type<FungibleTokenMetadataViews.FTDisplay>().identifier)
    Test.assert(metadata != nil, message: "Expected Vault metadata to be resolved from escrow but none was returned")

    // Confirm complete balance is still the same,
    // this time querying with the erc20 address
    completeBalances = getFullBalance(ownerAddr: alice.address, vaultIdentifier: nil, erc20AddressHex: associatedEVMAddressHex)
    Test.assert(completeBalances[0] == 0)
    Test.assert(completeBalances[1] == expectedTotalBalance)
    Test.assert(completeBalances[2] == expectedTotalBalance)

    // Query an account without the token to make sure balances are zero
    completeBalances = getFullBalance(ownerAddr: bob.address, vaultIdentifier: nil, erc20AddressHex: associatedEVMAddressHex)
    Test.assert(completeBalances[0] == 0)
    Test.assert(completeBalances[1] == 0)
    Test.assert(completeBalances[2] == 0)
}

access(all)
fun testCrossVMTransferCadenceNativeTokenFromEVMSucceeds() {
    snapshot = getCurrentBlockHeight()
    // Configure recipient's Vault first, using generic setup transaction
    let setupVaultResult = executeTransaction(
        "../transactions/example-assets/setup/setup_generic_vault.cdc",
        [exampleTokenIdentifier],
        bob
    )
    Test.expect(setupVaultResult, Test.beSucceeded())

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleTokenIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Confirm Alice is starting with 0.0 balance in their Cadence Vault
    let preCadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(0.0, preCadenceBalance)

    // Get Alice's ERC20 balance & convert to UFix64
    var evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: associatedEVMAddressHex)
    let decimals = getTokenDecimals(erc20AddressHex: associatedEVMAddressHex)
    let ufixValue = uint256ToUFix64(evmBalance, decimals: decimals)
    // Assert the converted balance is equal to the originally minted amount that was bridged in the previous step
    Test.assertEqual(exampleTokenMintAmount, ufixValue)

    // Execute bridge tokens from EVM to Cadence recipient (Bob in this case)
    let crossVMTransferResult = executeTransaction(
        "../transactions/bridge/tokens/bridge_tokens_to_any_cadence_address.cdc",
        [ exampleTokenIdentifier, evmBalance, bob.address ],
        alice
    )
    Test.expect(crossVMTransferResult, Test.beSucceeded())

    // Confirm ExampleToken balance has been bridged back to Alice's Cadence vault
    let recipientCadenceBalance = getBalance(ownerAddr: bob.address, storagePathIdentifier: "exampleTokenVault")
        ?? panic("Problem getting ExampleToken balance")
    Test.assertEqual(ufixValue, recipientCadenceBalance)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: associatedEVMAddressHex)
    Test.assertEqual(UInt256(0), evmBalance)
}

access(all)
fun testBridgeCadenceNativeTokenFromEVMSucceeds() {
    Test.reset(to: snapshot)

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleTokenIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

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
        vaultIdentifier: exampleTokenIdentifier,
        amount: evmBalance,
        beFailed: false
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

    let derivedERC20ContractName = deriveBridgedTokenContractName(evmAddressHex: erc20AddressHex)
    let bridgedVaultPathIdentifier = derivedERC20ContractName.concat("Vault")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    var evmBalance = balanceOf(evmAddressHex: aliceCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, evmBalance)

    // Confirm Alice does not yet have a bridged Vault configured
    var cadenceBalance = getBalance(ownerAddr: alice.address, storagePathIdentifier: bridgedVaultPathIdentifier)
    Test.assertEqual(nil, cadenceBalance)

    // Execute bridge from EVM
    bridgeTokensFromEVM(
        signer: alice,
        vaultIdentifier: buildTypeIdentifier(
            address: bridgeAccount.address,
            contractName: derivedERC20ContractName,
            resourceName: "Vault"
        ), amount: evmBalance,
        beFailed: false
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
    let bridgeCOAEscrowBalance = balanceOf(evmAddressHex: bridgeCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, bridgeCOAEscrowBalance)

    let viewsResolved = executeScript(
        "./scripts/resolve_bridged_token_views.cdc",
        [alice.address, bridgedVaultPathIdentifier]
    )
    Test.expect(viewsResolved, Test.beSucceeded())
    Test.assertEqual(true, viewsResolved.returnValue as! Bool? ?? panic("Problem resolving views"))
}

access(all)
fun testBridgeEVMNativeTokenToEVMSucceeds() {

    let derivedERC20ContractName = deriveBridgedTokenContractName(evmAddressHex: erc20AddressHex)
    let bridgedVaultPathIdentifier = derivedERC20ContractName.concat("Vault")
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

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
    var bridgeCOAEscrowBalance = balanceOf(evmAddressHex: bridgeCOAAddressHex, erc20AddressHex: erc20AddressHex)
    Test.assertEqual(erc20MintAmount, bridgeCOAEscrowBalance)

    // Execute bridge from EVM
    bridgeTokensToEVM(
        signer: alice,
        vaultIdentifier: buildTypeIdentifier(
            address: bridgeAccount.address,
            contractName: derivedERC20ContractName,
            resourceName: "Vault"
        ), amount: cadenceBalance,
        beFailed: false
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
