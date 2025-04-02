import Test
import BlockchainHelpers

import "MetadataViews"
import "EVM"
import "IFlowEVMNFTBridge"
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
    onboardByEVMAddress(signer: alice, evmAddressHex: erc721AddressHex, beFailed: true)
}

access(all)
fun testBridgeERC721FromEVMSucceeds() {
    Test.reset(to: snapshot)

    registerCrossVMNFT(
        signer: exampleEVMNativeNFTAccount,
        nftTypeIdentifier: exampleEVMNativeNFTIdentifier,
        fulfillmentMinterPath: ExampleEVMNativeNFT.FulfillmentMinterStoragePath,
        beFailed: false
    )

    snapshot = getCurrentBlockHeight()

    // create tmp account & init COA
    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOA = getCOAAddressHex(atFlowAddress: user.address)
    
    // mint the ERC721 to the user's COA
    let id: UInt256 = 42
    mintERC721(signer: exampleEVMNativeNFTAccount, erc721AddressHex: erc721AddressHex, recipient: EVM.addressFromString(userCOA), id: 42)
    // assert user COA is ownerOf
    var userIsOwner = isOwner(of: id, ownerEVMAddrHex: userCOA, erc721AddressHex: erc721AddressHex)
    Test.assertEqual(true, userIsOwner)

    // bridge from EVM
    bridgeNFTFromEVM(
        signer: user,
        nftIdentifier: exampleEVMNativeNFTIdentifier,
        erc721ID: id,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    // let evts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTFromEVM>())
    // Test.assertEqual(1, evts.length)
    // let bridgedEvt = evts[0] as! IFlowEVMNFTBridge.BridgedNFTFromEVM
    // Test.assertEqual(id, UInt256(bridgedEvt.id))
    // Test.assertEqual(id, bridgedEvt.evmID)
    // Test.assertEqual(userCOA, bridgedEvt.caller)
    // Test.assertEqual(erc721AddressHex, bridgedEvt.evmContractAddress)

    // // assert ERC721 is in escrow under bridge COA
    // let isEscrowed = isOwner(of: UInt256(id), ownerEVMAddrHex: getBridgeCOAAddressHex(), erc721AddressHex: erc721AddressHex)
    // Test.assert(isEscrowed, message: "ERC721 \(id) was not escrowed after bridging from EVM")
    // // ensure signer has the bridged NFT in their collection
    // let ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "ExampleCadenceNativeNFTCollection")
    // Test.assertEqual(1, ids.length)
    // Test.assertEqual(id, UInt256(ids[0]))
}

// TODO: Implement after bridgeNFTFromEVM route is updated for cross-VM NFTs
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

/* --- Case-Specific Helpers --- */

access(all)
fun setupAccount(_ user: Test.TestAccount, flowAmount: UFix64, coaAmount: UFix64) {
    // fund account
    transferFlow(signer: serviceAccount, recipient: user.address, amount: flowAmount)
    // create COA in account
    createCOA(signer: user, fundingAmount: coaAmount)
    // setup the collection in the user account
    setupGenericNFTCollection(signer: user, nftIdentifier: exampleEVMNativeNFTIdentifier)
}

access(all)
fun mintERC721(
    signer: Test.TestAccount,
    erc721AddressHex: String,
    recipient: EVM.EVMAddress,
    id: UInt256
) {
    let calldata = String.encodeHex(EVM.encodeABIWithSignature("safeMint(address,uint256)", [recipient, id]))
    let mintResult = executeTransaction(
        "../transactions/evm/call.cdc",
        [erc721AddressHex, calldata, UInt64(15_000_000), UInt(0)],
        signer
    )
    Test.expect(mintResult, Test.beSucceeded())
}