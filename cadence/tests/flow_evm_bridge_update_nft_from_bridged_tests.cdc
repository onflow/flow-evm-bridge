import Test
import BlockchainHelpers

import "MetadataViews"
import "EVM"
import "ExampleNFT"
import "IFlowEVMNFTBridge"
import "FlowEVMBridge"
import "FlowEVMBridgeUtils"
import "FlowEVMBridgeCustomAssociations"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)

// ExampleNFT
access(all) let exampleNFTIdentifier = "A.0000000000000008.ExampleNFT.NFT"
access(all) let exampleNFTTokenName = "Example NFT"
access(all) let exampleNFTTokenDescription = "Example NFT token description"
access(all) let exampleNFTTokenThumbnail = "https://examplenft.com/thumbnail.png"
access(all) var mintedNFTID: UInt64 = 0

// Bridge-related EVM contract values
access(all) var registryAddressHex: String = ""
access(all) var erc20DeployerAddressHex: String = ""
access(all) var erc721DeployerAddressHex: String = ""

// ERC721 values
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
    transferFlow(signer: serviceAccount, recipient: exampleNFTAccount.address, amount: 1_000.0)

    var err = Test.deployContract(
        name: "ExampleNFT",
        path: "../contracts/example-assets/ExampleNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun testOnboardAndUpdateExampleNFTSucceeds() {
    snapshot = getCurrentBlockHeight()

    var bridgedERC721AddressHex = ""
    var customERC721AddressHex = ""

    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)

    /* Permissionless Cadence-native onboarding */

    var typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(true, typeRequiresOnboarding)

    // Cadence-native permissionless onboarding
    onboardByTypeIdentifier(signer: user, typeIdentifier: exampleNFTIdentifier, beFailed: false)

    typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, typeRequiresOnboarding)

    var evts = Test.eventsOfType(Type<FlowEVMBridge.Onboarded>())
    Test.assertEqual(1, evts.length)
    let onboardedEvt = evts[0] as! FlowEVMBridge.Onboarded
    Test.assertEqual(exampleNFTIdentifier, onboardedEvt.type)

    bridgedERC721AddressHex = onboardedEvt.evmContractAddress
    Test.assertEqual(getAssociatedEVMAddressHex(with: exampleNFTIdentifier), bridgedERC721AddressHex)
    Test.assertEqual(bridgedERC721AddressHex, getAssociatedEVMAddressHex(with: exampleNFTIdentifier))

    // Previously onboarded with a bridged ERC721 representation in EVM
    typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, typeRequiresOnboarding)

    /* Setup ExampleNFT for custom cross-VM registration */

    // Create a COA in exampleNFT account
    createCOA(signer: exampleNFTAccount, fundingAmount: 0.0)
    // Deploy the cadence native ERC721
    customERC721AddressHex = deployCadenceNativeERC721(signer: exampleNFTAccount, underlyingERC721: nil)

    // Update the ExampleNFT contract from hex code
    updateExampleNFT(signer: exampleNFTAccount)

    // Validate onboarding status
    typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, typeRequiresOnboarding)

    /* Register custom cross-VM association */

    // Now register the updated ExampleNFT as cross-VM, associating the deployed ERC721
    registerCrossVMNFT(
        signer: exampleNFTAccount,
        nftTypeIdentifier: exampleNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: false
    )

    // Assert on events & saved
    evts = Test.eventsOfType(Type<FlowEVMBridgeCustomAssociations.CustomAssociationEstablished>())
    Test.assertEqual(1, evts.length)
    let associationEvt = evts[0] as! FlowEVMBridgeCustomAssociations.CustomAssociationEstablished
    Test.assertEqual(exampleNFTIdentifier, associationEvt.type)
    Test.assertEqual(customERC721AddressHex.toLower(), "0x\(associationEvt.evmContractAddress)")
    Test.assertEqual(UInt8(0), associationEvt.nativeVMRawValue)
    Test.assertEqual(true, associationEvt.updatedFromBridged)
    Test.assertEqual(nil, associationEvt.fulfillmentMinterType)

    Test.assertEqual("0x\(getAssociatedEVMAddressHex(with: exampleNFTIdentifier))", customERC721AddressHex.toLower())
}

access(all)
fun testBridgeNFTToEVMSucceeds() {
    Test.reset(to: snapshot)

    // create tmp account & setup
    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOA = getCOAAddressHex(atFlowAddress: user.address)

    // Onboard & update
    onboardByTypeIdentifier(signer: user, typeIdentifier: exampleNFTIdentifier, beFailed: false)
    // Create a COA in exampleNFT account
    createCOA(signer: exampleNFTAccount, fundingAmount: 0.0)
    // Deploy the cadence native ERC721
    let customERC721AddressHex = deployCadenceNativeERC721(signer: exampleNFTAccount, underlyingERC721: nil)

    // Update the ExampleNFT contract from hex code
    updateExampleNFT(signer: exampleNFTAccount)

    // Register the updated ExampleNFT with the custom ERC721
    registerCrossVMNFT(
        signer: exampleNFTAccount,
        nftTypeIdentifier: exampleNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: false
    )

    // mint the NFT to the tmp account
    mintNFT(signer: exampleNFTAccount, recipient: user.address)
    let ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, ids.length)
    let id = ids[0]

    // bridge to EVM
    bridgeNFTToEVM(
        signer: user,
        nftIdentifier: exampleNFTIdentifier,
        nftID: id,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )

    // assert on events
    let bridgedEvts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTToEVM>())
    Test.assertEqual(1, bridgedEvts.length)
    let bridgedEvt = bridgedEvts[0] as! IFlowEVMNFTBridge.BridgedNFTToEVM
    Test.assertEqual(id, bridgedEvt.id)
    Test.assertEqual(userCOA, bridgedEvt.to)
    Test.assertEqual(customERC721AddressHex.toLower(), "0x\(bridgedEvt.evmContractAddress)")
    // assert NFT is in locked in Cadence-side escrow
    let isLocked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: id)
    Test.assert(isLocked, message: "Expected ExampleNFT to be locked in escrow, but NFT \(id) was not locked")
    // ensure signer's COA owns the custom ERC721 token
    let userIsOwner = isOwner(of: UInt256(id), ownerEVMAddrHex: userCOA, erc721AddressHex: customERC721AddressHex)
    Test.assert(userIsOwner, message: "Expected user COA \(userCOA) to owner ERC721 \(customERC721AddressHex) \(id) after bridging, but ownership was not found")
}

access(all)
fun testBridgeERC721FromEVMSucceeds() {
    Test.reset(to: snapshot)

    // create tmp account & setup
    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOA = getCOAAddressHex(atFlowAddress: user.address)

    // Onboard & update
    onboardByTypeIdentifier(signer: user, typeIdentifier: exampleNFTIdentifier, beFailed: false)
    // Create a COA in exampleNFT account
    createCOA(signer: exampleNFTAccount, fundingAmount: 0.0)
    // Deploy the cadence native ERC721 & assign the deployment address
    let customERC721AddressHex = deployCadenceNativeERC721(signer: exampleNFTAccount, underlyingERC721: nil)

    // Update the ExampleNFT contract
    updateExampleNFT(signer: exampleNFTAccount)

    // Register the updated ExampleNFT with the custom ERC721
    registerCrossVMNFT(
        signer: exampleNFTAccount,
        nftTypeIdentifier: exampleNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: false
    )

    // mint the NFT to the tmp account
    mintNFT(signer: exampleNFTAccount, recipient: user.address)
    var ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, ids.length)
    let id = ids[0]

    // bridge to EVM
    bridgeNFTToEVM(
        signer: user,
        nftIdentifier: exampleNFTIdentifier,
        nftID: id,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )

    // assert NFT is in locked in Cadence-side escrow
    let isLocked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: id)
    Test.assert(isLocked, message: "Expected ExampleNFT to be locked in escrow, but NFT \(id) was not locked")
    // ensure signer's COA owns the custom ERC721 token
    let userIsOwner = isOwner(of: UInt256(id), ownerEVMAddrHex: userCOA, erc721AddressHex: customERC721AddressHex)
    Test.assert(userIsOwner, message: "Expected user COA \(userCOA) to owner ERC721 \(customERC721AddressHex) \(id) after bridging, but ownership was not found")

    bridgeNFTFromEVM(
        signer: user,
        nftIdentifier: exampleNFTIdentifier,
        erc721ID: UInt256(id),
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )

    // assert on events
    let evts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTFromEVM>())
    Test.assertEqual(1, evts.length)
    let bridgedEvt = evts[0] as! IFlowEVMNFTBridge.BridgedNFTFromEVM
    Test.assertEqual(id, bridgedEvt.id)
    Test.assertEqual(UInt256(id), bridgedEvt.evmID)
    Test.assertEqual(userCOA, bridgedEvt.caller)
    Test.assertEqual(customERC721AddressHex, "0x\(bridgedEvt.evmContractAddress)")

    // assert ERC721 is in escrow under bridge COA
    let isEscrowed = isOwner(of: UInt256(id), ownerEVMAddrHex: getBridgeCOAAddressHex(), erc721AddressHex: customERC721AddressHex)
    Test.assert(isEscrowed, message: "ERC721 \(id) was not escrowed after bridging from EVM")

    // ensure signer has the bridged NFT in their collection
    ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, ids.length)
    Test.assertEqual(id, ids[0])
}

access(all)
fun testBridgeFromEVMAfterUpdatingSucceeds() {
    Test.reset(to: snapshot)

    // create tmp account & setup
    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOA = getCOAAddressHex(atFlowAddress: user.address)

    // mint the NFT to the tmp account
    mintNFT(signer: exampleNFTAccount, recipient: user.address)
    var ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, ids.length)
    let id = ids[0]

    // bridge to EVM - onboards via default permissionless route, deploying bridged ERC721 & minting to user
    bridgeNFTToEVM(
        signer: user,
        nftIdentifier: exampleNFTIdentifier,
        nftID: id,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    // get the bridge-defined ERC721 address post-onboarding
    let bridgedERC721 = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    // assert on events
    var bridgedToEvts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTToEVM>())
    Test.assertEqual(1, bridgedToEvts.length)
    var bridgedToEvt = bridgedToEvts[0] as! IFlowEVMNFTBridge.BridgedNFTToEVM
    Test.assertEqual(id, bridgedToEvt.id)
    Test.assertEqual(userCOA, bridgedToEvt.to)
    Test.assertEqual(bridgedERC721, bridgedToEvt.evmContractAddress)

    // Ensure ownership of proper tokens
    let userOwnsBridgedToken = isOwner(of: UInt256(id), ownerEVMAddrHex: userCOA, erc721AddressHex: bridgedERC721)
    let isLocked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: id)
    Test.assert(userOwnsBridgedToken, message: "User was not bridged NFT \(id)")
    Test.assert(isLocked, message: "Example NFT \(id) is not locked in Cadence-side escrow after bridging to EVM")

    /* Cross-VM Update & Registration */
    //
    // Create a COA in exampleNFT account
    createCOA(signer: exampleNFTAccount, fundingAmount: 0.0)
    // Deploy the cadence native ERC721 & assign the deployment address
    let customERC721AddressHex = deployCadenceNativeERC721(signer: exampleNFTAccount, underlyingERC721: nil)
    // Update the ExampleNFT contract
    updateExampleNFT(signer: exampleNFTAccount)
    // Register the updated ExampleNFT with the custom ERC721
    registerCrossVMNFT(
        signer: exampleNFTAccount,
        nftTypeIdentifier: exampleNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: false
    )

    // bridge NFT from EVM
    bridgeNFTFromEVM(
        signer: user,
        nftIdentifier: exampleNFTIdentifier,
        erc721ID: UInt256(id),
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    // assert on events
    let bridgedFromEvts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTFromEVM>())
    Test.assertEqual(1, bridgedFromEvts.length)
    let bridgedFromEvt = bridgedFromEvts[0] as! IFlowEVMNFTBridge.BridgedNFTFromEVM
    Test.assertEqual(id, bridgedFromEvt.id)
    Test.assertEqual(UInt256(id), bridgedFromEvt.evmID)
    Test.assertEqual(userCOA, bridgedFromEvt.caller)
    Test.assertEqual(customERC721AddressHex, "0x\(bridgedFromEvt.evmContractAddress)")

    // ensure user owns ExampleNFT
    ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, ids.length)
    Test.assertEqual(id, ids[0])

    // importantly, ensure bridged ERC721 no longer exists & user owns bridged custom ERC721
    let exists = erc721Exists(id: UInt256(id), erc721AddressHex: bridgedERC721)
    Test.assert(!exists, message: "Bridged ERC721 still exists after bridging from EVM as updated cross-VM NFT")

    // bridge back to EVM - should now bridge as the custom ERC721
    bridgeNFTToEVM(
        signer: user,
        nftIdentifier: exampleNFTIdentifier,
        nftID: id,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    // assert on events
    bridgedToEvts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTToEVM>())
    Test.assertEqual(2, bridgedToEvts.length)
    bridgedToEvt = bridgedToEvts[1] as! IFlowEVMNFTBridge.BridgedNFTToEVM
    Test.assertEqual(id, bridgedToEvt.id)
    Test.assertEqual(userCOA, bridgedToEvt.to)
    Test.assertEqual(customERC721AddressHex, "0x\(bridgedToEvt.evmContractAddress)")

    // Ensure user was bridged the correct ERC721
    let userOwnsCustomToken = isOwner(of: UInt256(id), ownerEVMAddrHex: userCOA, erc721AddressHex: customERC721AddressHex)
    Test.assert(userOwnsBridgedToken, message: "User was not bridged custom ERC721 \(customERC721AddressHex) #\(id)")
}

access(all)
fun testMigrateBridgedERC721TransactionSucceeds() {
    Test.reset(to: snapshot)

    // create tmp account & setup
    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOA = getCOAAddressHex(atFlowAddress: user.address)

    // mint the NFT to the tmp account
    mintNFT(signer: exampleNFTAccount, recipient: user.address)
    var ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, ids.length)
    let id = ids[0]

    // bridge to EVM - onboards via default permissionless route, deploying bridged ERC721 & minting to user
    bridgeNFTToEVM(
        signer: user,
        nftIdentifier: exampleNFTIdentifier,
        nftID: id,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    // get the bridge-defined ERC721 address post-onboarding
    let bridgedERC721 = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    // assert on events
    var bridgedToEvts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTToEVM>())
    Test.assertEqual(1, bridgedToEvts.length)
    var bridgedToEvt = bridgedToEvts[0] as! IFlowEVMNFTBridge.BridgedNFTToEVM
    Test.assertEqual(id, bridgedToEvt.id)
    Test.assertEqual(userCOA, bridgedToEvt.to)
    Test.assertEqual(bridgedERC721, bridgedToEvt.evmContractAddress)

    // Ensure ownership of proper tokens
    let userOwnsBridgedToken = isOwner(of: UInt256(id), ownerEVMAddrHex: userCOA, erc721AddressHex: bridgedERC721)
    let isLocked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: id)
    Test.assert(userOwnsBridgedToken, message: "User was not bridged NFT \(id)")
    Test.assert(isLocked, message: "Example NFT \(id) is not locked in Cadence-side escrow after bridging to EVM")

    /* Cross-VM Update & Registration */
    //
    // Create a COA in exampleNFT account
    createCOA(signer: exampleNFTAccount, fundingAmount: 0.0)
    // Deploy the cadence native ERC721 & assign the deployment address
    let customERC721AddressHex = deployCadenceNativeERC721(signer: exampleNFTAccount, underlyingERC721: nil)
    // Update the ExampleNFT contract
    updateExampleNFT(signer: exampleNFTAccount)
    // Register the updated ExampleNFT with the custom ERC721
    registerCrossVMNFT(
        signer: exampleNFTAccount,
        nftTypeIdentifier: exampleNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: false
    )

    // migrate the bridged ERC721 to the custom ERC721
    let migrationResult = executeTransaction(
        "../transactions/bridge/nft/batch_migrate_bridged_evm_nft.cdc",
        [exampleNFTIdentifier, [UInt256(id)]],
        user
    )
    Test.expect(migrationResult, Test.beSucceeded())
    // assert on events
    bridgedToEvts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTToEVM>())
    Test.assertEqual(2, bridgedToEvts.length)
    bridgedToEvt = bridgedToEvts[1] as! IFlowEVMNFTBridge.BridgedNFTToEVM
    Test.assertEqual(id, bridgedToEvt.id)
    Test.assertEqual(userCOA, bridgedToEvt.to)
    Test.assertEqual(customERC721AddressHex, "0x\(bridgedToEvt.evmContractAddress)")

    // Ensure user now owns the correct ERC721
    let userOwnsCustomToken = isOwner(of: UInt256(id), ownerEVMAddrHex: userCOA, erc721AddressHex: customERC721AddressHex)
    Test.assert(userOwnsBridgedToken, message: "User was not bridged custom ERC721 \(customERC721AddressHex) #\(id)")
}

access(all)
fun testMigrateBridgedERC721FromWrappedSucceeds() {
    Test.reset(to: snapshot)

    // create tmp account & setup
    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOA = getCOAAddressHex(atFlowAddress: user.address)

    // mint the NFT to the tmp account
    mintNFT(signer: exampleNFTAccount, recipient: user.address)
    var ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "cadenceExampleNFTCollection")
    Test.assertEqual(1, ids.length)
    let id = ids[0]

    // bridge to EVM - onboards via default permissionless route, deploying bridged ERC721 & minting to user
    bridgeNFTToEVM(
        signer: user,
        nftIdentifier: exampleNFTIdentifier,
        nftID: id,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    // get the bridge-defined ERC721 address post-onboarding
    let bridgedERC721 = getAssociatedEVMAddressHex(with: exampleNFTIdentifier)
    // assert on events
    var bridgedToEvts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTToEVM>())
    Test.assertEqual(1, bridgedToEvts.length)
    var bridgedToEvt = bridgedToEvts[0] as! IFlowEVMNFTBridge.BridgedNFTToEVM
    Test.assertEqual(id, bridgedToEvt.id)
    Test.assertEqual(userCOA, bridgedToEvt.to)
    Test.assertEqual(bridgedERC721, bridgedToEvt.evmContractAddress)

    // Ensure ownership of proper tokens
    let userOwnsBridgedToken = isOwner(of: UInt256(id), ownerEVMAddrHex: userCOA, erc721AddressHex: bridgedERC721)
    let isLocked = isNFTLocked(nftTypeIdentifier: exampleNFTIdentifier, id: id)
    Test.assert(userOwnsBridgedToken, message: "User was not bridged NFT \(id)")
    Test.assert(isLocked, message: "Example NFT \(id) is not locked in Cadence-side escrow after bridging to EVM")

    /* Cross-VM Update & Registration */
    //
    // Create a COA in exampleNFT account
    createCOA(signer: exampleNFTAccount, fundingAmount: 0.0)
    // Deploy the cadence native ERC721 & assign the deployment address, wrapping the bridged ERC721 token
    let customERC721AddressHex = deployCadenceNativeERC721(signer: exampleNFTAccount, underlyingERC721: EVM.addressFromString(bridgedERC721))
    // Update the ExampleNFT contract
    updateExampleNFT(signer: exampleNFTAccount)
    // Register the updated ExampleNFT with the custom ERC721
    registerCrossVMNFT(
        signer: exampleNFTAccount,
        nftTypeIdentifier: exampleNFTIdentifier,
        fulfillmentMinterPath: nil,
        beFailed: false
    )


    // Before migrating the NFT, wrap the bridged ERC721 token
    var calldata = String.encodeHex(EVM.encodeABIWithSignature(
            "approve(address,uint256)",
            [EVM.addressFromString(customERC721AddressHex), UInt256(id)]
        ))
    let approveResult = executeTransaction(
        "../transactions/evm/call.cdc",
        [bridgedERC721, calldata, UInt64(15_000_000), UInt(0)],
        user
    )
    Test.expect(approveResult, Test.beSucceeded())
    calldata = String.encodeHex(EVM.encodeABIWithSignature(
            "depositFor(address,uint256[])",
            [EVM.addressFromString(userCOA), [UInt256(id)]]
        ))
    let wrapResult = executeTransaction(
        "../transactions/evm/call.cdc",
        [customERC721AddressHex, calldata, UInt64(15_000_000), UInt(0)],
        user
    )
    Test.expect(wrapResult, Test.beSucceeded())

    // migrate the bridged ERC721 to the custom ERC721
    let migrationResult = executeTransaction(
        "../transactions/bridge/nft/batch_migrate_bridged_evm_nft.cdc",
        [exampleNFTIdentifier, [UInt256(id)]],
        user
    )
    Test.expect(migrationResult, Test.beSucceeded())
    // assert on events
    bridgedToEvts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTToEVM>())
    Test.assertEqual(2, bridgedToEvts.length)
    bridgedToEvt = bridgedToEvts[1] as! IFlowEVMNFTBridge.BridgedNFTToEVM
    Test.assertEqual(id, bridgedToEvt.id)
    Test.assertEqual(userCOA, bridgedToEvt.to)
    Test.assertEqual(customERC721AddressHex, "0x\(bridgedToEvt.evmContractAddress)")

    // Ensure user now owns the correct ERC721
    let userOwnsCustomToken = isOwner(of: UInt256(id), ownerEVMAddrHex: userCOA, erc721AddressHex: customERC721AddressHex)
    Test.assert(userOwnsBridgedToken, message: "User was not bridged custom ERC721 \(customERC721AddressHex) #\(id)")
}

/* --- Case-Specific Helpers --- */

access(all)
fun setupAccount(_ user: Test.TestAccount, flowAmount: UFix64, coaAmount: UFix64) {
    // fund account
    transferFlow(signer: serviceAccount, recipient: user.address, amount: flowAmount)
    // create COA in account
    createCOA(signer: user, fundingAmount: coaAmount)
    // setup the collection in the user account
    let setupResult = executeTransaction(
        "../transactions/example-assets/example-nft/setup_collection.cdc",
        [],
        user
    )
    Test.expect(setupResult, Test.beSucceeded())
}

access(all)
fun deployCadenceNativeERC721(signer: Test.TestAccount, underlyingERC721: EVM.EVMAddress?): String {
    // Create the constructor args
    let constructorArgs = [
        "ExampleNFT",
        "XMPL",
        exampleNFTAccount.address.toString(),
        exampleNFTIdentifier,
        EVM.addressFromString(getBridgeCOAAddressHex())
    ]
    var finalBytecode = getCadenceNativeERC721Bytecode().decodeHex()
    if underlyingERC721 != nil {
        // insert the underlyingERC721 into the constructor args at the second to last place
        constructorArgs.insert(at: constructorArgs.length - 1, underlyingERC721!)
        // Update the ERC721 bytecode
        finalBytecode = getCadenceNativeERC721WithWrapperBytecode().decodeHex()
    }
    // Encode final bytecode with constructor args & deploy 
    let encodedArgs = EVM.encodeABI(constructorArgs)
    finalBytecode = finalBytecode.concat(encodedArgs)
    let erc721DeployResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [String.encodeHex(finalBytecode), UInt64(15_000_000), 0.0],
        signer
    )
    Test.expect(erc721DeployResult, Test.beSucceeded())

    // Get the deployed ERC721 address
    var evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    let customERC721AddressHex = getEVMAddressHexFromEvents(evts, idx: evts.length - 1)

    // Save that deployed address to exampleNFT account storage at /storage/erc721ContractAddress
    let saveAddressResult = executeTransaction(
        "./transactions/save_erc721_address.cdc",
        [customERC721AddressHex],
        signer
    )
    Test.expect(saveAddressResult, Test.beSucceeded())

    return "0x\(customERC721AddressHex)"
}

access(all)
fun updateExampleNFT(signer: Test.TestAccount) {
    let updateResult = executeTransaction(
        "./transactions/update_contract.cdc",
        ["ExampleNFT", getExampleNFTAsCrossVMCode()],
        signer
    )
    Test.expect(updateResult, Test.beSucceeded())
}

access(all)
fun mintNFT(
    signer: Test.TestAccount,
    recipient: Address
) {
    let mintResult = executeTransaction(
        "../transactions/example-assets/example-nft/mint_nft.cdc",
        [recipient, exampleNFTTokenName, exampleNFTTokenDescription, exampleNFTTokenThumbnail, [], [], []],
        signer
    )
    Test.expect(mintResult, Test.beSucceeded())
}
