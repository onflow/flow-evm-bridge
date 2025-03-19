import Test
import BlockchainHelpers

import "MetadataViews"
import "EVM"
import "ExampleEVMNativeNFT"
import "MaliciousNFTFulfillmentMinter"
import "FlowEVMBridgeCustomAssociations"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleEVMNativeNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let alice = Test.createAccount()
access(all) let bob = Test.createAccount()

// ExampleEVMNativeNFT
access(all) let exampleEVMNativeNFTIdentifier = "A.0000000000000008.ExampleEVMNativeNFT.NFT"
access(all) var mintedNFTID: UInt64 = 0

// Bridge-related EVM contract values
access(all) var registryAddressHex: String = ""
access(all) var erc20DeployerAddressHex: String = ""
access(all) var erc721DeployerAddressHex: String = ""

// ERC721 values
access(all) var erc721AddressHex: String = ""
access(all) let erc721ID: UInt256 = 42

// Fee initialization values
access(all) let expectedOnboardFee = 1.0
access(all) let expectedBaseFee = 0.001

// Test height snapshot for test state resets
access(all) var snapshot: UInt64 = 0

access(all)
fun setup() {
    setupBridge(bridgeAccount: bridgeAccount, serviceAccount: serviceAccount, unpause: true)

    // Configure example ERC20 account with a COA
    transferFlow(signer: serviceAccount, recipient: exampleEVMNativeNFTAccount.address, amount: 1_000.0)

    var err = Test.deployContract(
        name: "ExampleEVMNativeNFT",
        path: "../contracts/example-assets/cross-vm-nfts/ExampleEVMNativeNFT.cdc",
        arguments: [getEVMNativeERC721Bytecode()]
    )
    Test.expect(err, Test.beNil())
    erc721AddressHex = ExampleEVMNativeNFT.getEVMContractAddress().toString()

    // Deploying to test malicious registration with unrelated NFTFulfillmentMinter
    err = Test.deployContract(
        name: "MaliciousNFTFulfillmentMinter",
        path: "./contracts/MaliciousNFTFulfillmentMinter.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Unpause the bridge
    updateBridgePauseStatus(signer: bridgeAccount, pause: false)
}

access(all)
fun testRegisterEVMNativeNFTAsCrossVMSucceeds() {
    snapshot = getCurrentBlockHeight()

    var requiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    registerCrossVMNFT(
        signer: exampleEVMNativeNFTAccount,
        nftTypeIdentifier: exampleEVMNativeNFTIdentifier,
        fulfillmentMinterPath: ExampleEVMNativeNFT.FulfillmentMinterStoragePath,
        beFailed: false
    )
    let associatedEVMAddress = getAssociatedEVMAddressHex(with: exampleEVMNativeNFTIdentifier)
    Test.assertEqual(erc721AddressHex, associatedEVMAddress)
    let associatedType = getTypeAssociated(with: erc721AddressHex)
    Test.assertEqual(exampleEVMNativeNFTIdentifier, associatedType)

    requiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(false, requiresOnboarding)

    let evts = Test.eventsOfType(Type<FlowEVMBridgeCustomAssociations.CustomAssociationEstablished>())
    Test.assertEqual(1, evts.length)
    let associationEvt = evts[0] as! FlowEVMBridgeCustomAssociations.CustomAssociationEstablished
    Test.assertEqual(exampleEVMNativeNFTIdentifier, associationEvt.type)
    Test.assertEqual(erc721AddressHex, associationEvt.evmContractAddress)
    Test.assertEqual(UInt8(1), associationEvt.nativeVMRawValue)
    Test.assertEqual(false, associationEvt.updatedFromBridged)
    Test.assertEqual(Type<@ExampleEVMNativeNFT.NFTMinter>().identifier, associationEvt.fulfillmentMinterType!)
}

access(all)
fun testRegisterAgainFails() {
    Test.reset(to: snapshot)

    registerCrossVMNFT(
        signer: exampleEVMNativeNFTAccount,
        nftTypeIdentifier: exampleEVMNativeNFTIdentifier,
        fulfillmentMinterPath: ExampleEVMNativeNFT.FulfillmentMinterStoragePath,
        beFailed: false
    )

    registerCrossVMNFT(
        signer: exampleEVMNativeNFTAccount,
        nftTypeIdentifier: exampleEVMNativeNFTIdentifier,
        fulfillmentMinterPath: ExampleEVMNativeNFT.FulfillmentMinterStoragePath,
        beFailed: true
    )
}

access(all)
fun testRegisterEVMNativeNFTWithoutMinterFails() {
    Test.reset(to: snapshot)

    var requiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    registerCrossVMNFT(
        signer: exampleEVMNativeNFTAccount,
        nftTypeIdentifier: exampleEVMNativeNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: true
    )
}

access(all)
fun testRegisterEVMNativeNFTWithUnrelatedMinterFails() {
    Test.reset(to: snapshot)

    var requiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    registerCrossVMNFT(
        signer: Test.getAccount(0x0000000000000009),
        nftTypeIdentifier: exampleEVMNativeNFTIdentifier,
        fulfillmentMinterPath: MaliciousNFTFulfillmentMinter.StoragePath,
        beFailed: true
    )
}

access(all)
fun testOnboardEVMNativeNFTFails() {
    Test.reset(to: snapshot)

    var requiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    Test.assertEqual(true, requiresOnboarding)

    // EVM-native cross-VM NFTs require NFTFulfillmentMinter Capability when onboarding
    // Onboarding via the permissionless path should fail as the Capability is not provided
    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc721AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beFailed())
}

access(all)
fun testBridgeERC721FromEVMSucceeds() {
    // create tmp account
    // fund account
    // create COA in account
    // mint the ERC721 from the right account to the tmp account COA
    // assert COA is ownerOf
    // bridge from EVM
    // assert on events
    // assert EVM NFT is in escrow under bridge COA
    // ensure signer has the bridged NFT in their collection
    // assert metadata values from Cadence NFT 
}

access(all)
fun testBridgeNFTToEVMSucceeds() {
    // create tmp account
    // fund account
    // create COA in account
    // mint the ERC721 from the right account to the tmp account COA
    // assert on ownerOf
    // bridge from EVM
    // assert on events
    // assert EVM NFT is in escrow under bridge COA
    // ensure signer has the bridged NFT in their collection
    // assert metadata values from Cadence NFT
    // bridge to EVM
    // assert on events
}