import Test
import BlockchainHelpers

import "FungibleToken"
import "NonFungibleToken"

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
access(all) let erc20MintAmount: UInt256 = 100_000_000_000_000_000_000

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
        name: "EVMBridgeRouter",
        path: "../contracts/bridge/EVMBridgeRouter.cdc",
        arguments: [bridgeAccount.address, "FlowEVMBridge"]
    )
    Test.expect(err, Test.beNil())

    // Transfer ERC721 deployer some $FLOW
    transferFlow(signer: serviceAccount, recipient: exampleERCAccount.address, amount: 1_000.0)
    // Configure bridge account with a COA
    createCOA(signer: exampleERCAccount, fundingAmount: 10.0)

    // Deploy the ERC721 from EVMDeployer (simply to capture deploye EVM contract address)
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

access(all)
fun testCreateCOASucceeds() {
    transferFlow(signer: serviceAccount, recipient: alice.address, amount: 1_000.0)
    createCOA(signer: alice, fundingAmount: 100.0)

    let coaAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, coaAddressHex!.length)
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
    let setupCollectionResult = executeTransaction(
        "../transactions/example-assets/example-token/setup_vault.cdc",
        [],
        alice
    )
    Test.expect(setupCollectionResult, Test.beSucceeded())

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
fun testOnboardNFTByTypeSucceeds() {
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
fun testOnboardERC721ByEVMAddressSucceeds() {
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
        "../transactions/bridge/onboard_by_evm_address.cdc",
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
        "../transactions/bridge/onboard_by_evm_address.cdc",
        [erc721AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testOnboardTokenByTypeSucceeds() {
    var onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding.cdc",
        [exampleTokenIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    var requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    var onboardingResult = executeTransaction(
        "../transactions/bridge/onboard_by_type.cdc",
        [exampleTokenIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    onboaringRequiredResult = executeScript(
        "../scripts/bridge/type_requires_onboarding.cdc",
        [exampleTokenIdentifier]
    )
    Test.expect(onboaringRequiredResult, Test.beSucceeded())
    requiresOnboarding = onboaringRequiredResult.returnValue as! Bool? ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    onboardingResult = executeTransaction(
        "../transactions/bridge/onboard_by_type.cdc",
        [exampleTokenIdentifier],
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
        "../transactions/bridge/onboard_by_evm_address.cdc",
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
        "../transactions/bridge/onboard_by_evm_address.cdc",
        [erc20AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testBridgeCadenceNativeNFTToEVMSucceeds() {
    var aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, aliceOwnedIDs.length)

    var aliceCOAAddressHex = getCOAAddressHex(atFlowAddress: alice.address)
    Test.assertEqual(40, aliceCOAAddressHex.length)

    // Execute bridge to EVM
    bridgeNFTToEVM(signer: alice, contractAddr: exampleNFTAccount.address, contractName: "ExampleNFT", nftID: aliceOwnedIDs[0])

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
    bridgeNFTFromEVM(signer: alice, contractAddr: exampleNFTAccount.address, contractName: "ExampleNFT", erc721ID: UInt256(mintedNFTID))

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

    bridgeNFTFromEVM(signer: alice, contractAddr: bridgeAccount.address, contractName: derivedERC721ContractName, erc721ID: erc721ID)

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

    bridgeNFTToEVM(signer: alice, contractAddr: bridgeAccount.address, contractName: derivedERC721ContractName, nftID: aliceOwnedIDs[0])

    aliceOwnedIDs = getIDs(ownerAddr: alice.address, storagePathIdentifier: bridgedCollectionPathIdentifier)
    Test.assertEqual(0, aliceOwnedIDs.length)

    let aliceIsOwner = isOwner(of: erc721ID, ownerEVMAddrHex: aliceCOAAddressHex, erc721AddressHex: erc721AddressHex)
    Test.assertEqual(true, aliceIsOwner)
}

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

/* --- Script Helpers --- */

access(all)
fun getCOAAddressHex(atFlowAddress: Address): String {
    let coaAddressResult = executeScript(
        "../scripts/evm/get_evm_address_string.cdc",
        [atFlowAddress]
    )
    Test.expect(coaAddressResult, Test.beSucceeded())
    return coaAddressResult.returnValue as! String? ?? panic("Problem getting COA address as String")
}

access(all)
fun getAssociatedEVMAddressHex(with typeIdentifier: String): String {
    var associatedEVMAddressResult = executeScript(
        "../scripts/bridge/get_associated_evm_address.cdc",
        [typeIdentifier]
    )
    Test.expect(associatedEVMAddressResult, Test.beSucceeded())
    return associatedEVMAddressResult.returnValue as! String? ?? panic("Problem getting EVM Address as String")
}

access(all)
fun getDeployedAddressFromDeployer(name: String): String {
    let erc721AddressResult = executeScript(
        "../scripts/test/get_deployed_address_string_from_deployer.cdc",
        [name]
    )
    Test.expect(erc721AddressResult, Test.beSucceeded())
    return erc721AddressResult.returnValue as! String? ?? panic("Problem getting COA address as String")
}

access(all)
fun getIDs(ownerAddr: Address, storagePathIdentifier: String): [UInt64] {
    let idResult = executeScript(
        "../scripts/nft/get_ids.cdc",
        [ownerAddr, storagePathIdentifier]
    )
    Test.expect(idResult, Test.beSucceeded())
    return idResult.returnValue as! [UInt64]? ?? panic("Problem getting NFT IDs")
}

access(all)
fun getBalance(ownerAddr: Address, storagePathIdentifier: String): UFix64? {
    let balanceResult = executeScript(
        "../scripts/tokens/get_balance.cdc",
        [ownerAddr, storagePathIdentifier]
    )
    Test.expect(balanceResult, Test.beSucceeded())
    return balanceResult.returnValue as! UFix64?
}

access(all)
fun balanceOf(evmAddressHex: String, erc20AddressHex: String): UInt256 {
    let balanceOfResult = executeScript(
        "../scripts/utils/balance_of.cdc",
        [evmAddressHex, erc20AddressHex]
    )
    Test.expect(balanceOfResult, Test.beSucceeded())
    return balanceOfResult.returnValue as! UInt256? ?? panic("Problem getting ERC20 balance")
}

access(all)
fun getTokenDecimals(erc20AddressHex: String): UInt8 {
    let decimalsResult = executeScript(
        "../scripts/utils/get_token_decimals.cdc",
        [erc20AddressHex]
    )
    Test.expect(decimalsResult, Test.beSucceeded())
    return decimalsResult.returnValue as! UInt8? ?? panic("Problem getting ERC20 decimals")
}

access(all)
fun ufix64ToUInt256(_ value: UFix64, decimals: UInt8): UInt256 {
    let convertedResult = executeScript(
        "../scripts/utils/ufix64_to_uint256.cdc",
        [value, decimals]
    )
    Test.expect(convertedResult, Test.beSucceeded())
    return convertedResult.returnValue as! UInt256? ?? panic("Problem converting UFix64 to UInt256")
}

access(all)
fun uint256ToUFix64(_ value: UInt256, decimals: UInt8): UFix64 {
    let convertedResult = executeScript(
        "../scripts/utils/uint256_to_ufix64.cdc",
        [value, decimals]
    )
    Test.expect(convertedResult, Test.beSucceeded())
    return convertedResult.returnValue as! UFix64? ?? panic("Problem converting UInt256 to UFix64")
}

access(all)
fun isOwner(of: UInt256, ownerEVMAddrHex: String, erc721AddressHex: String): Bool {
    let isOwnerResult = executeScript(
        "../scripts/utils/is_owner.cdc",
        [of, ownerEVMAddrHex, erc721AddressHex]
    )
    Test.expect(isOwnerResult, Test.beSucceeded())
    return isOwnerResult.returnValue as! Bool? ?? panic("Problem getting owner status")
}

access(all)
fun deriveBridgedNFTContractName(evmAddressHex: String): String {
    let nameResult = executeScript(
        "../scripts/utils/derive_bridged_nft_contract_name.cdc",
        [evmAddressHex]
    )
    Test.expect(nameResult, Test.beSucceeded())
    return nameResult.returnValue as! String? ?? panic("Problem getting derived contract name")
}

access(all)
fun deriveBridgedTokenContractName(evmAddressHex: String): String {
    let nameResult = executeScript(
        "../scripts/utils/derive_bridged_token_contract_name.cdc",
        [evmAddressHex]
    )
    Test.expect(nameResult, Test.beSucceeded())
    return nameResult.returnValue as! String? ?? panic("Problem getting derived contract name")
}

/* --- Transaction Helpers --- */

access(all)
fun transferFlow(signer: Test.TestAccount, recipient: Address, amount: UFix64) {
    let transferResult = executeTransaction(
        "../transactions/flow-token/transfer_flow.cdc",
        [recipient, amount],
        signer
    )
    Test.expect(transferResult, Test.beSucceeded())
}

access(all)
fun createCOA(signer: Test.TestAccount, fundingAmount: UFix64) {
    let createCOAResult = executeTransaction(
        "../transactions/evm/create_account.cdc",
        [fundingAmount],
        signer
    )
    Test.expect(createCOAResult, Test.beSucceeded())
}

access(all)
fun bridgeNFTToEVM(signer: Test.TestAccount, contractAddr: Address, contractName: String, nftID: UInt64) {
    let bridgeResult = executeTransaction(
        "../transactions/bridge/bridge_nft_to_evm.cdc",
        [contractAddr, contractName, nftID],
        signer
    )
    Test.expect(bridgeResult, Test.beSucceeded())

    var events = Test.eventsOfType(Type<NonFungibleToken.Withdrawn>())
    let withdrawnEvent = events[events.length - 1] as! NonFungibleToken.Withdrawn
    Test.assertEqual(nftID, withdrawnEvent.id)
    Test.assertEqual(signer.address, withdrawnEvent.from!)

    events = Test.eventsOfType(Type<NonFungibleToken.Deposited>())
    let depositedEvent = events[events.length - 1] as! NonFungibleToken.Deposited
    Test.assertEqual(nftID, depositedEvent.id)
    Test.assertEqual(bridgeAccount.address, depositedEvent.to!)
}

access(all)
fun bridgeNFTFromEVM(signer: Test.TestAccount, contractAddr: Address, contractName: String, erc721ID: UInt256) {
    let bridgeResult = executeTransaction(
        "../transactions/bridge/bridge_nft_from_evm.cdc",
        [contractAddr, contractName, erc721ID],
        signer
    )
    Test.expect(bridgeResult, Test.beSucceeded())

    var events = Test.eventsOfType(Type<NonFungibleToken.Withdrawn>())
    let withdrawnEvent = events[events.length - 1] as! NonFungibleToken.Withdrawn
    Test.assertEqual(bridgeAccount.address, withdrawnEvent.from!)

    events = Test.eventsOfType(Type<NonFungibleToken.Deposited>())
    let depositedEvent = events[events.length - 1] as! NonFungibleToken.Deposited
    Test.assertEqual(signer.address, depositedEvent.to!)
}

access(all)
fun bridgeTokensToEVM(signer: Test.TestAccount, contractAddr: Address, contractName: String, amount: UFix64) {
    let bridgeResult = executeTransaction(
        "../transactions/bridge/bridge_tokens_to_evm.cdc",
        [contractAddr, contractName, amount],
        signer
    )
    Test.expect(bridgeResult, Test.beSucceeded())

    // TODO: Add event assertions on bridge events. We can't currently import the event types to do this
    //      so state assertions beyond call scope will need to suffice for now
}

access(all)
fun bridgeTokensFromEVM(signer: Test.TestAccount, contractAddr: Address, contractName: String, amount: UInt256) {
    let bridgeResult = executeTransaction(
        "../transactions/bridge/bridge_tokens_from_evm.cdc",
        [contractAddr, contractName, amount],
        signer
    )
    Test.assert(bridgeResult.error == nil, message: "Could not construct Vault type of: " .concat(contractAddr.toString()).concat(".").concat(contractName).concat(".Vault"))

    // TODO: Add event assertions on bridge events. We can't currently import the event types to do this
    //      so state assertions beyond call scope will need to suffice for now
}
