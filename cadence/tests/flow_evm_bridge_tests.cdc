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
access(all) var mintedNFTID: UInt64 = 0

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
    // Initialize EVMBlocklist resource in account storage
    let initBlocklistResult = executeTransaction(
        "../transactions/bridge/admin/blocklist/init_blocklist.cdc",
        [],
        bridgeAccount
    )
    Test.expect(initBlocklistResult, Test.beSucceeded())

    // Deploy registry
    let registryDeploymentResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getRegistryBytecode(), UInt64(15_000_000), 0.0],
        bridgeAccount
    )
    Test.expect(registryDeploymentResult, Test.beSucceeded())
    // Deploy ERC20Deployer
    let erc20DeployerDeploymentResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getERC20DeployerBytecode(), UInt64(15_000_000), 0.0],
        bridgeAccount
    )
    Test.expect(erc20DeployerDeploymentResult, Test.beSucceeded())
    // Deploy ERC721Deployer
    let erc721DeployerDeploymentResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getERC721DeployerBytecode(), UInt64(15_000_000), 0.0],
        bridgeAccount
    )
    Test.expect(erc721DeployerDeploymentResult, Test.beSucceeded())
    // Assign contract addresses
    var evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    Test.assertEqual(5, evts.length)
    registryAddressHex = getEVMAddressHexFromEvents(evts, idx: 2)
    erc20DeployerAddressHex = getEVMAddressHexFromEvents(evts, idx: 3)
    erc721DeployerAddressHex = getEVMAddressHexFromEvents(evts, idx: 4)

    // Deploy factory
    let deploymentResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getCompiledFactoryBytecode(), UInt64(15_000_000), 0.0],
        bridgeAccount
    )
    Test.expect(deploymentResult, Test.beSucceeded())
    // Assign the factory contract address
    evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    Test.assertEqual(6, evts.length)
    let factoryAddressHex = getEVMAddressHexFromEvents(evts, idx: 5)
    Test.assertEqual(factoryAddressHex.length, 40)

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
        name: "FlowEVMBridgeHandlers",
        path: "../contracts/bridge/FlowEVMBridgeHandlers.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    /* Integrate EVM bridge contract */

    // Set factory as registrar in registry
    let setRegistrarResult = executeTransaction(
        "../transactions/bridge/admin/evm/set_registrar.cdc",
        [registryAddressHex],
        bridgeAccount
    )
    Test.expect(setRegistrarResult, Test.beSucceeded())
    // Set registry as registry in factory
    let setRegistryResult = executeTransaction(
        "../transactions/bridge/admin/evm/set_deployment_registry.cdc",
        [registryAddressHex],
        bridgeAccount
    )
    Test.expect(setRegistryResult, Test.beSucceeded())
    // Set factory as delegatedDeployer in erc20Deployer
    var setDelegatedDeployerResult = executeTransaction(
        "../transactions/bridge/admin/evm/set_delegated_deployer.cdc",
        [erc20DeployerAddressHex],
        bridgeAccount
    )
    Test.expect(setDelegatedDeployerResult, Test.beSucceeded())
    // Set factory as delegatedDeployer in erc721Deployer
    setDelegatedDeployerResult = executeTransaction(
        "../transactions/bridge/admin/evm/set_delegated_deployer.cdc",
        [erc721DeployerAddressHex],
        bridgeAccount
    )
    Test.expect(setDelegatedDeployerResult, Test.beSucceeded())
    // add erc20Deployer under "ERC20" tag to factory
    var addDeployerResult = executeTransaction(
        "../transactions/bridge/admin/evm/add_deployer.cdc",
        ["ERC20", erc20DeployerAddressHex],
        bridgeAccount
    )
    Test.expect(addDeployerResult, Test.beSucceeded())
    // add erc721Deployer under "ERC721" tag to factory
    addDeployerResult = executeTransaction(
        "../transactions/bridge/admin/evm/add_deployer.cdc",
        ["ERC721", erc721DeployerAddressHex],
        bridgeAccount
    )
    Test.expect(addDeployerResult, Test.beSucceeded())

    /* End EVM bridge integration txns */

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

    // Configure example ERC20 account with a COA
    transferFlow(signer: serviceAccount, recipient: exampleERCAccount.address, amount: 1_000.0)
    createCOA(signer: exampleERCAccount, fundingAmount: 10.0)

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

    // Configure metadata views for bridged NFTS & FTs
    let setBridgedNFTDisplayViewResult = executeTransaction(
        "../transactions/bridge/admin/metadata/set_bridged_nft_display_view.cdc",
        [
            "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg", // thumbnailURI
            Type<MetadataViews.HTTPFile>().identifier, // thumbnailFileTypeIdentifier
            nil // ipfsFilePath
        ],
        bridgeAccount
    )
    Test.expect(setBridgedNFTDisplayViewResult, Test.beSucceeded())

    let socialsDict: {String: String} = {}
    let setBridgedNFTCollectionDisplayResult = executeTransaction(
        "../transactions/bridge/admin/metadata/set_bridged_nft_collection_display_view.cdc",
        [
            "https://port.flow.com", // externalURL
            "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg", // squareImageURI
            Type<MetadataViews.HTTPFile>().identifier, // squareImageFileTypeIdentifier
            nil, // squareImageIPFSFilePath
            "image/svg+xml", // squareImageMediaType
            "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg", // bannerImageURI
            Type<MetadataViews.HTTPFile>().identifier, // bannerImageFileTypeIdentifier
            nil, // bannerImageIPFSFilePath
            "image/svg+xml", // bannerImageMediaType
            socialsDict // socialsDict
        ],
        bridgeAccount
    )
    Test.expect(setBridgedNFTCollectionDisplayResult, Test.beSucceeded())

    let setFTDisplayResult = executeTransaction(
        "../transactions/bridge/admin/metadata/set_bridged_ft_display_view.cdc",
        [
            "https://port.flow.com", // externalURL
            "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg", // logoURI
            Type<MetadataViews.HTTPFile>().identifier, // logoFileTypeIdentifier
            nil, // logoIPFSFilePath
            "image/svg+xml", // logoMediaType
            socialsDict // socialsDict
        ],
        bridgeAccount
    )
    Test.expect(setFTDisplayResult, Test.beSucceeded())
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
fun testBridgeFlowToEVMSucceeds() {
    // Get $FLOW balances before, making assertions based on values from previous case
    let cadenceBalanceBefore = getBalance(ownerAddr: alice.address, storagePathIdentifier: "flowTokenVault")
        ?? panic("Problem getting $FLOW balance")
    Test.assertEqual(900.0, cadenceBalanceBefore)

    // Get EVM $FLOW balance before
    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    let evmBalanceBefore = getEVMFlowBalance(of: aliceCOAAddressHex)
    Test.assertEqual(100.0, evmBalanceBefore)

    // Execute bridge to EVM
    let bridgeAmount = 100.0
    bridgeTokensToEVM(
        signer: alice,
        vaultIdentifier: buildTypeIdentifier(
            address: Address(0x03),
            contractName: "FlowToken",
            resourceName: "Vault"
        ), amount: bridgeAmount,
        beFailed: false
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
    let hasCollection = executeScript(
        "../scripts/nft/has_collection_configured.cdc",
        [exampleNFTIdentifier, alice.address]
    )
    Test.expect(hasCollection, Test.beSucceeded())
    Test.assertEqual(true, hasCollection.returnValue as! Bool? ?? panic("Problem getting collection status"))

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

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testOnboardAndBridgeNFTToEVMSucceeds() {
    // Revert to state before ExampleNFT was onboarded
    Test.reset(to: snapshot)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)
    let aliceID = aliceOwnedIDs[0]

    var requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, requiresOnboarding)

    // Execute bridge NFT to EVM - should also onboard the NFT type
    bridgeNFTToEVM(
        signer: alice,
        nftIdentifier: exampleNFTIdentifier,
        nftID: aliceID,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())

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
fun testOnboardAndCrossVMTransferNFTToEVMSucceeds() {
    // Revert to state before ExampleNFT was onboarded
    Test.reset(to: snapshot)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)
    let aliceID = aliceOwnedIDs[0]

    let recipient = getCOAAddressHex(atFlowAddress: bob.address)

    var requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, requiresOnboarding)

    // Execute bridge NFT to EVM recipient - should also onboard the NFT type
    let crossVMTransferResult = executeTransaction(
        "../transactions/bridge/nft/bridge_nft_to_any_evm_address.cdc",
        [ exampleNFTIdentifier, aliceID, recipient ],
        alice
    )
    Test.expect(crossVMTransferResult, Test.beSucceeded())

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Confirm the NFT is no longer in Alice's Collection
    aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(0, aliceOwnedIDs.length)

    // Confirm ownership on EVM side with Alice COA as owner of ERC721 representation
    let isOwnerResult = executeScript(
        "../scripts/utils/is_owner.cdc",
        [UInt256(mintedNFTID), recipient, associatedEVMAddressHex]
    )
    Test.expect(isOwnerResult, Test.beSucceeded())
    Test.assertEqual(true, isOwnerResult.returnValue as! Bool? ?? panic("Problem getting owner status"))
}

access(all)
fun testOnboardTokenByTypeSucceeds() {
    var requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleTokenIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(true, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    requiresOnboarding = typeRequiresOnboardingByIdentifier(exampleTokenIdentifier)
        ?? panic("Problem getting onboarding status for type")
    Test.assertEqual(false, requiresOnboarding)

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
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

    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())

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

    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())

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
    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc721AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())

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

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc721AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    requiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
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

    var requiresOnboarding = evmAddressRequiresOnboarding(erc20AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc20AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    requiresOnboarding = evmAddressRequiresOnboarding(erc20AddressHex)
        ?? panic("Problem getting onboarding requirement")
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
    Test.assertEqual(1, aliceOwnedIDs.length)

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
    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Execute bridge to EVM
    bridgeNFTToEVM(
        signer: alice,
        nftIdentifier: exampleNFTIdentifier,
        nftID: aliceOwnedIDs[0],
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
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

    let isNFTLocked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: mintedNFTID)
    Test.assertEqual(true, isNFTLocked)

    let metadata = resolveLockedNFTView(bridgeAddress: bridgeAccount.address, nftTypeIdentifier: exampleNFTIdentifier, id: UInt256(mintedNFTID), viewIdentifier: Type<MetadataViews.Display>().identifier)
    Test.assert(metadata != nil, message: "Expected NFT metadata to be resolved from escrow but none was returned")
}

access(all)
fun testCrossVMTransferCadenceNativeNFTFromEVMSucceeds() {
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
    var aliceIsOwner = isOwner(of: UInt256(mintedNFTID), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)

    // Execute bridge NFT from EVM to Cadence recipient (Bob in this case)
    let crossVMTransferResult = executeTransaction(
        "../transactions/bridge/nft/bridge_nft_to_any_cadence_address.cdc",
        [ exampleNFTIdentifier, UInt256(mintedNFTID), bob.address ],
        alice
    )
    Test.expect(crossVMTransferResult, Test.beSucceeded())

    // Assert ownership of the bridged NFT in EVM has transferred
    aliceIsOwner = isOwner(of: UInt256(mintedNFTID), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(false, aliceIsOwner)

    // Assert the NFT is now in Bob's Collection
    let bobOwnedIDs = getIDs(ownerAddr: bob.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, bobOwnedIDs.length)
    Test.assertEqual(mintedNFTID, bobOwnedIDs[0])

    let isNFTLocked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: mintedNFTID)
    Test.assertEqual(false, isNFTLocked)
}

access(all)
fun testBridgeCadenceNativeNFTFromEVMSucceeds() {
    Test.reset(to: snapshot)
    let aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    let associatedEVMAddressHex = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    Test.assertEqual(40, associatedEVMAddressHex.length)

    // Assert ownership of the bridged NFT in EVM
    var aliceIsOwner = isOwner(of: UInt256(mintedNFTID), ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: associatedEVMAddressHex)
    Test.assertEqual(true, aliceIsOwner)

    // Execute bridge from EVM
    bridgeNFTFromEVM(
        signer: alice,
        nftIdentifier: exampleNFTIdentifier,
        erc721ID: UInt256(mintedNFTID),
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
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
        nftID: aliceOwnedIDs[0],
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

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)

    // Execute bridge to EVM
    bridgeTokensToEVM(
        signer: alice,
        vaultIdentifier: exampleTokenIdentifier,
        amount: cadenceBalance,
        beFailed: false
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

    // Confirm the token is locked
    let lockedBalance = getLockedTokenBalance(vaultTypeIdentifier: exampleTokenIdentifier) ?? panic("Problem getting locked balance")
    Test.assertEqual(exampleTokenMintAmount, lockedBalance)

    let metadata = resolveLockedTokenView(bridgeAddress: bridgeAccount.address, vaultTypeIdentifier: exampleTokenIdentifier, viewIdentifier: Type<FungibleTokenMetadataViews.FTDisplay>().identifier)
    Test.assert(metadata != nil, message: "Expected Vault metadata to be resolved from escrow but none was returned")
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
