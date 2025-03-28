import Test
import BlockchainHelpers

import "MetadataViews"
import "EVM"
import "ExampleCadenceNativeNFT"
import "FlowEVMBridgeCustomAssociations"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleCadenceNativeNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let alice = Test.createAccount()
access(all) let bob = Test.createAccount()

// ExampleCadenceNativeNFT
access(all) let exampleCadenceNativeNFTIdentifier = "A.0000000000000008.ExampleCadenceNativeNFT.NFT"
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
    transferFlow(signer: serviceAccount, recipient: exampleCadenceNativeNFTAccount.address, amount: 1_000.0)

    var err = Test.deployContract(
        name: "ExampleCadenceNativeNFT",
        path: "../contracts/example-assets/cross-vm-nfts/ExampleCadenceNativeNFT.cdc",
        arguments: [getCadenceNativeERC721Bytecode(), "Example Cadence-Native NFT", "XMPL"]
    )
    Test.expect(err, Test.beNil())
    erc721AddressHex = ExampleCadenceNativeNFT.getEVMContractAddress().toString()
}

access(all)
fun testRegisterCadenceNativeNFTAsCrossVMSucceeds() {
    snapshot = getCurrentBlockHeight()

    var addrRequiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement by address")
    var typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleCadenceNativeNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(true, addrRequiresOnboarding)
    Test.assertEqual(true, typeRequiresOnboarding)

    registerCrossVMNFT(
        signer: exampleCadenceNativeNFTAccount,
        nftTypeIdentifier: exampleCadenceNativeNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: false
    )
    let associatedEVMAddress = getAssociatedEVMAddressHex(with: exampleCadenceNativeNFTIdentifier)
    Test.assertEqual(erc721AddressHex, associatedEVMAddress)
    let associatedType = getTypeAssociated(with: erc721AddressHex)
    Test.assertEqual(exampleCadenceNativeNFTIdentifier, associatedType)

    addrRequiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleCadenceNativeNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, addrRequiresOnboarding)
    Test.assertEqual(false, typeRequiresOnboarding)

    let evts = Test.eventsOfType(Type<FlowEVMBridgeCustomAssociations.CustomAssociationEstablished>())
    Test.assertEqual(1, evts.length)
    let associationEvt = evts[0] as! FlowEVMBridgeCustomAssociations.CustomAssociationEstablished
    Test.assertEqual(exampleCadenceNativeNFTIdentifier, associationEvt.type)
    Test.assertEqual(erc721AddressHex, associationEvt.evmContractAddress)
    Test.assertEqual(UInt8(0), associationEvt.nativeVMRawValue)
    Test.assertEqual(false, associationEvt.updatedFromBridged)
    Test.assertEqual(nil, associationEvt.fulfillmentMinterType)
}

access(all)
fun testRegisterAgainFails() {
    Test.reset(to: snapshot)

    registerCrossVMNFT(
        signer: exampleCadenceNativeNFTAccount,
        nftTypeIdentifier: exampleCadenceNativeNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: false
    )

    let addrRequiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    let typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleCadenceNativeNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, addrRequiresOnboarding)
    Test.assertEqual(false, typeRequiresOnboarding)

    registerCrossVMNFT(
        signer: exampleCadenceNativeNFTAccount,
        nftTypeIdentifier: exampleCadenceNativeNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: true
    )
}

access(all)
fun testOnboardCadenceNativeNFTByIdentifierSucceeds() {
    Test.reset(to: snapshot)

    // Cadence-native onboarding
    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleCadenceNativeNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    let addrRequiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    let typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleCadenceNativeNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, addrRequiresOnboarding)
    Test.assertEqual(false, typeRequiresOnboarding)

    let evts = Test.eventsOfType(Type<FlowEVMBridgeCustomAssociations.CustomAssociationEstablished>())
    Test.assertEqual(1, evts.length)
    let associationEvt = evts[0] as! FlowEVMBridgeCustomAssociations.CustomAssociationEstablished
    Test.assertEqual(exampleCadenceNativeNFTIdentifier, associationEvt.type)
    Test.assertEqual(erc721AddressHex, associationEvt.evmContractAddress)
    Test.assertEqual(UInt8(0), associationEvt.nativeVMRawValue)
    Test.assertEqual(false, associationEvt.updatedFromBridged)
    Test.assertEqual(nil, associationEvt.fulfillmentMinterType)
}

access(all)
fun testOnboardCadenceNativeNFTByEVMAddressSucceeds() {
    Test.reset(to: snapshot)

    // Cadence-native onboarding
    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_evm_address.cdc",
        [erc721AddressHex],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    let addrRequiresOnboarding = evmAddressRequiresOnboarding(erc721AddressHex)
        ?? panic("Problem getting onboarding requirement")
    let typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleCadenceNativeNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, addrRequiresOnboarding)
    Test.assertEqual(false, typeRequiresOnboarding)

    let evts = Test.eventsOfType(Type<FlowEVMBridgeCustomAssociations.CustomAssociationEstablished>())
    Test.assertEqual(1, evts.length)
    let associationEvt = evts[0] as! FlowEVMBridgeCustomAssociations.CustomAssociationEstablished
    Test.assertEqual(exampleCadenceNativeNFTIdentifier, associationEvt.type)
    Test.assertEqual(erc721AddressHex, associationEvt.evmContractAddress)
    Test.assertEqual(UInt8(0), associationEvt.nativeVMRawValue)
    Test.assertEqual(false, associationEvt.updatedFromBridged)
    Test.assertEqual(nil, associationEvt.fulfillmentMinterType)
}

access(all)
fun testBridgeNFTToEVMSucceeds() {
    snapshot = getCurrentBlockHeight()
    // create tmp account & setup
    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)

    // mint the NFT to the user & get the id
    mintNFT(signer: exampleCadenceNativeNFTAccount, recipient: user.address, name: "Example Cadence-Native NFT", description: "Test Minting")
    let ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "ExampleCadenceNativeNFTCollection")
    Test.assertEqual(1, ids.length)

    // bridge to EVM
    bridgeNFTToEVM(
        signer: user,
        nftIdentifier: exampleCadenceNativeNFTIdentifier,
        nftID: ids[0],
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    // assert on events
    // assert ERC721 is in escrow under bridge COA
    // ensure user owns the fulfilled ERC721 token
    // assert metadata values from Cadence NFT
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
fun setupAccount(_ user: Test.TestAccount, flowAmount: UFix64, coaAmount: UFix64) {
    // fund account
    transferFlow(signer: serviceAccount, recipient: user.address, amount: flowAmount)
    // create COA in account
    createCOA(signer: user, fundingAmount: coaAmount)
    // setup the collection in the user account
    setupGenericNFTCollection(signer: user, nftIdentifier: exampleCadenceNativeNFTIdentifier)
}

access(all)
fun mintNFT(
    signer: Test.TestAccount,
    recipient: Address,
    name: String,
    description: String
) {
    let mintResult = executeTransaction("../transactions/example-assets/example-cadence-native-nft/mint_nft.cdc", [recipient, name, description], signer)
    Test.expect(mintResult, Test.beSucceeded())
}