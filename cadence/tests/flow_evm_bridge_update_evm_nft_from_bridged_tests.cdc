import Test
import BlockchainHelpers

import "MetadataViews"
import "NonFungibleToken"
import "EVM"
import "ExampleEVMNativeNFTGivenEVMAddress"
import "IFlowEVMNFTBridge"
import "FlowEVMBridge"
import "FlowEVMBridgeUtils"
import "FlowEVMBridgeCustomAssociations"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let erc721Account = Test.getAccount(0x0000000000000008)
access(all) var erc721COAHex = ""

// Bridged NFT values
access(all) var bridgedNFTIdentifier = ""

// Custom Cadence Cross-VM NFT values
access(all) var customNFTIdentifier: String = ""

// ERC721 values
access(all) var proxyAddressHex: String = ""
access(all) var erc721AddressHex: String = ""
access(all) let erc721ID: UInt256 = 42
access(all) let name: String = "EVMNativeERC721"
access(all) let symbol: String = "EVMXMPL"
access(all) let contractMetadata: String = "data:application/json;utf8,{\"name\": \"EVMNativeERC721\", \"symbol\": \"EVMXMPL\"}"

// Test height snapshot for test state resets
access(all) var snapshot: UInt64 = 0

access(all)
fun setup() {
    setupBridge(bridgeAccount: bridgeAccount, serviceAccount: serviceAccount, unpause: true)

    // Configure ERC721 account with a COA
    transferFlow(signer: serviceAccount, recipient: erc721Account.address, amount: 1_000.0)

    // setup erc721Account for EVM calls with a COA
    createCOA(signer: erc721Account, fundingAmount: 1.0)
    erc721COAHex = getCOAAddressHex(atFlowAddress: erc721Account.address)

    // deploy the upgradable ERC721
    let erc721DeploymentResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getEVMNativeERC721UpgradableV1Bytecode(), UInt64(15_000_000), 0.0],
        erc721Account
    )
    Test.expect(erc721DeploymentResult, Test.beSucceeded())
    // assign the implementation address
    var evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    erc721AddressHex = getEVMAddressHexFromEvents(evts, idx: evts.length - 1)

    // construct the ERC1967Proxy bytecode including constructor args
    let initializeBytes = EVM.EVMBytes(value: EVM.encodeABIWithSignature(
            "initialize(string,string,address,string)",
            [name, symbol, EVM.addressFromString(erc721COAHex), contractMetadata]
        ))
    let constructorBytecode = EVM.encodeABI([
            EVM.addressFromString(erc721AddressHex),
            initializeBytes
        ])
    let finalProxyBytecode = getERC1967ProxyBytecode().decodeHex().concat(constructorBytecode)
    // deploy the ERC1967Proxy contract
    let proxyDeploymentResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [String.encodeHex(finalProxyBytecode), UInt64(15_000_000), 0.0],
        erc721Account
    )
    Test.expect(proxyDeploymentResult, Test.beSucceeded())
    // assign the proxy address - this will be used to interact with the underlying contract
    evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    proxyAddressHex = getEVMAddressHexFromEvents(evts, idx: evts.length - 1)
}

access(all)
fun testOnboardAndUpdateERC721Succeeds() {
    snapshot = getCurrentBlockHeight()

    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)

    /* Permissionless EVM-native onboarding */

    var erc721RequiresOnboarding = evmAddressRequiresOnboarding(proxyAddressHex)
        ?? panic("Problem getting onboarding requirement by erc721 address")
    Test.assertEqual(true, erc721RequiresOnboarding)

    // Cadence-native permissionless onboarding
    onboardByEVMAddress(signer: user, evmAddressHex: proxyAddressHex, beFailed: false)

    erc721RequiresOnboarding = evmAddressRequiresOnboarding(proxyAddressHex)
        ?? panic("Problem getting onboarding requirement by erc721 address")
    Test.assertEqual(false, erc721RequiresOnboarding)

    var evts = Test.eventsOfType(Type<FlowEVMBridge.BridgeDefiningContractDeployed>())
    Test.assertEqual(1, evts.length)
    let onboardedEvt = evts[0] as! FlowEVMBridge.BridgeDefiningContractDeployed
    Test.assertEqual(proxyAddressHex, onboardedEvt.evmContractAddress)

    // Assign the bridged NFT type after onboarding
    bridgedNFTIdentifier = getTypeAssociated(with: proxyAddressHex)

    /* Setup EVM-native NFT for custom cross-VM registration */

    // Deploy the evm-native Cadence NFT contract
    let err = Test.deployContract(
            name: "ExampleEVMNativeNFTGivenEVMAddress",
            path: "../contracts/example-assets/cross-vm-nfts/ExampleEVMNativeNFTGivenEVMAddress.cdc",
            arguments: [proxyAddressHex] // NOTE: set the proxy address as the associated EVM address
        )
    Test.expect(err, Test.beNil())
    customNFTIdentifier = Type<@ExampleEVMNativeNFTGivenEVMAddress.NFT>().identifier
    upgradeERC721()

    /* Register custom cross-VM association */

    // Now register the updated ExampleNFT as cross-VM, associating the deployed ERC721
    registerCrossVMNFT(
        signer: erc721Account,
        nftTypeIdentifier: customNFTIdentifier,
        fulfillmentMinterPath: ExampleEVMNativeNFTGivenEVMAddress.FulfillmentMinterStoragePath,
        beFailed: false
    )

    // Assert on events & saved
    evts = Test.eventsOfType(Type<FlowEVMBridgeCustomAssociations.CustomAssociationEstablished>())
    Test.assertEqual(1, evts.length)
    let associationEvt = evts[0] as! FlowEVMBridgeCustomAssociations.CustomAssociationEstablished
    Test.assertEqual(customNFTIdentifier, associationEvt.type)
    Test.assertEqual("0x\(proxyAddressHex.toLower())", "0x\(associationEvt.evmContractAddress)")
    Test.assertEqual(UInt8(1), associationEvt.nativeVMRawValue) // EVM-native
    Test.assertEqual(true, associationEvt.updatedFromBridged)
    Test.assertEqual(Type<@ExampleEVMNativeNFTGivenEVMAddress.NFTMinter>().identifier, associationEvt.fulfillmentMinterType!)

    Test.assertEqual("0x\(getAssociatedEVMAddressHex(with: customNFTIdentifier))", "0x\(proxyAddressHex.toLower())")
    Test.assertEqual(customNFTIdentifier, getTypeAssociated(with: proxyAddressHex))

    // ensure legacy & updated types are available via Config contract
    let legacyType = getLegacyTypeForCustomCrossVMType(typeIdentifier: customNFTIdentifier)!
    let customType = getUpdatedCustomCrossVMTypeForLegacyType(typeIdentifier: bridgedNFTIdentifier)!
    Test.assertEqual(bridgedNFTIdentifier, legacyType.identifier)
    Test.assertEqual(customNFTIdentifier, customType.identifier)
}

access(all)
fun testBridgeERC721FromEVMSucceeds() {
    Test.reset(to: snapshot)

    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOAHex = getCOAAddressHex(atFlowAddress: user.address)

    // Cadence-native permissionless onboarding
    onboardByEVMAddress(signer: user, evmAddressHex: proxyAddressHex, beFailed: false)
    // Assign the bridged NFT type after onboarding
    bridgedNFTIdentifier = getTypeAssociated(with: proxyAddressHex)

    /* Setup EVM-native NFT for custom cross-VM registration */

    // Deploy the evm-native Cadence NFT contract
    let err = Test.deployContract(
            name: "ExampleEVMNativeNFTGivenEVMAddress",
            path: "../contracts/example-assets/cross-vm-nfts/ExampleEVMNativeNFTGivenEVMAddress.cdc",
            arguments: [proxyAddressHex] // NOTE: set the proxy address as the associated EVM address
        )
    Test.expect(err, Test.beNil())

    customNFTIdentifier = Type<@ExampleEVMNativeNFTGivenEVMAddress.NFT>().identifier

    upgradeERC721()

    /* Register custom cross-VM association */

    // Now register the updated ExampleNFT as cross-VM, associating the deployed ERC721
    registerCrossVMNFT(
        signer: erc721Account,
        nftTypeIdentifier: customNFTIdentifier,
        fulfillmentMinterPath: ExampleEVMNativeNFTGivenEVMAddress.FulfillmentMinterStoragePath,
        beFailed: false
    )

    /* Mint the ERC721 & Bridge from EVM */

    let mintCalldata = EVM.encodeABIWithSignature("safeMint(address,uint256)", [EVM.addressFromString(userCOAHex), erc721ID])
    let mintRes = executeTransaction(
        "../transactions/evm/call.cdc",
        [proxyAddressHex, String.encodeHex(mintCalldata), UInt64(15_000_000), UInt(0)],
        erc721Account
    )
    Test.expect(mintRes, Test.beSucceeded())
    Test.assertEqual(ownerOf(id: erc721ID, erc721AddressHex: proxyAddressHex)!, userCOAHex)

    bridgeNFTFromEVM(
        signer: user,
        nftIdentifier: customNFTIdentifier,
        erc721ID: erc721ID,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    let evts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTFromEVM>())
    Test.assertEqual(1, evts.length)
    let bridgedEvt = evts[0] as! IFlowEVMNFTBridge.BridgedNFTFromEVM
    Test.assertEqual(UInt64(erc721ID), bridgedEvt.id)
    Test.assertEqual(erc721ID, bridgedEvt.evmID)
    Test.assertEqual(userCOAHex, bridgedEvt.caller)
    Test.assertEqual("0x\(proxyAddressHex)", "0x\(bridgedEvt.evmContractAddress)")

    // assert ERC721 is in escrow under bridge COA
    let isEscrowed = isOwner(of: erc721ID, ownerEVMAddrHex: getBridgeCOAAddressHex(), erc721AddressHex: proxyAddressHex)
    Test.assert(isEscrowed, message: "ERC721 \(erc721ID) was not escrowed after bridging from EVM")

    // ensure signer has the bridged NFT in their collection
    let ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "ExampleEVMNativeNFTCollection")
    Test.assertEqual(1, ids.length)
    Test.assertEqual(UInt64(erc721ID), ids[0])
}

access(all)
fun testBridgeERC721ToEVMSucceeds() {
    Test.reset(to: snapshot)

    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOAHex = getCOAAddressHex(atFlowAddress: user.address)

    // Cadence-native permissionless onboarding
    onboardByEVMAddress(signer: user, evmAddressHex: proxyAddressHex, beFailed: false)
    // Assign the bridged NFT type after onboarding
    bridgedNFTIdentifier = getTypeAssociated(with: proxyAddressHex)

    /* Setup EVM-native NFT for custom cross-VM registration */

    // Deploy the evm-native Cadence NFT contract
    let err = Test.deployContract(
            name: "ExampleEVMNativeNFTGivenEVMAddress",
            path: "../contracts/example-assets/cross-vm-nfts/ExampleEVMNativeNFTGivenEVMAddress.cdc",
            arguments: [proxyAddressHex] // NOTE: set the proxy address as the associated EVM address
        )
    Test.expect(err, Test.beNil())
    customNFTIdentifier = Type<@ExampleEVMNativeNFTGivenEVMAddress.NFT>().identifier
    upgradeERC721()

    /* Register custom cross-VM association */

    // Now register the updated ExampleNFT as cross-VM, associating the deployed ERC721
    registerCrossVMNFT(
        signer: erc721Account,
        nftTypeIdentifier: customNFTIdentifier,
        fulfillmentMinterPath: ExampleEVMNativeNFTGivenEVMAddress.FulfillmentMinterStoragePath,
        beFailed: false
    )

    /* Mint the ERC721 & Bridge from EVM */

    let mintCalldata = EVM.encodeABIWithSignature("safeMint(address,uint256)", [EVM.addressFromString(userCOAHex), erc721ID])
    let mintRes = executeTransaction(
        "../transactions/evm/call.cdc",
        [proxyAddressHex, String.encodeHex(mintCalldata), UInt64(15_000_000), UInt(0)],
        erc721Account
    )
    Test.expect(mintRes, Test.beSucceeded())

    bridgeNFTFromEVM(
        signer: user,
        nftIdentifier: customNFTIdentifier,
        erc721ID: erc721ID,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    bridgeNFTToEVM(
        signer: user,
        nftIdentifier: customNFTIdentifier,
        nftID: UInt64(erc721ID),
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    let evts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTToEVM>())
    Test.assertEqual(1, evts.length)
    let bridgedEvt = evts[0] as! IFlowEVMNFTBridge.BridgedNFTToEVM
    Test.assertEqual(UInt64(erc721ID), bridgedEvt.id)
    Test.assertEqual(erc721ID, bridgedEvt.evmID)
    Test.assertEqual(userCOAHex, bridgedEvt.to)
    Test.assertEqual("0x\(proxyAddressHex)", "0x\(bridgedEvt.evmContractAddress)")

    // assert ERC721 is in escrow under bridge COA
    let userIsOwner = isOwner(of: erc721ID, ownerEVMAddrHex: userCOAHex, erc721AddressHex: proxyAddressHex)
    Test.assert(userIsOwner, message: "ERC721 \(erc721ID) was not bridged to user after bridging to EVM")

    // ensure Cadence NFT is escrowed
    let isLocked = isNFTLocked(nftTypeIdentifier: customNFTIdentifier, id: UInt64(erc721ID))
    Test.assert(isLocked, message: "Cadence NFT was not locked in NFT escrow after bridging to EVM")
}

access(all)
fun testBridgeERC721ToEVMAfterUpdatingSucceeds() {
    Test.reset(to: snapshot)

    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOAHex = getCOAAddressHex(atFlowAddress: user.address)

    // Cadence-native permissionless onboarding
    onboardByEVMAddress(signer: user, evmAddressHex: proxyAddressHex, beFailed: false)
    // Assign the bridged NFT type after onboarding
    bridgedNFTIdentifier = getTypeAssociated(with: proxyAddressHex)

    /* Mint the ERC721 & Bridge from EVM as Bridged NFT */

    let mintCalldata = EVM.encodeABIWithSignature("safeMint(address,uint256)", [EVM.addressFromString(userCOAHex), erc721ID])
    let mintRes = executeTransaction(
        "../transactions/evm/call.cdc",
        [proxyAddressHex, String.encodeHex(mintCalldata), UInt64(15_000_000), UInt(0)],
        erc721Account
    )
    Test.expect(mintRes, Test.beSucceeded())

    bridgeNFTFromEVM(
        signer: user,
        nftIdentifier: bridgedNFTIdentifier,
        erc721ID: erc721ID,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )

    // get the bridged NFT ID
    let derivedERC721ContractName = deriveBridgedNFTContractName(evmAddressHex: proxyAddressHex)
    let bridgedCollectionPathIdentifier = derivedERC721ContractName.concat("Collection")
    let ids = getIDs(ownerAddr: user.address, storagePathIdentifier: bridgedCollectionPathIdentifier)
    Test.assertEqual(1, ids.length)
    let bridgedNFTID = ids[0]

    /* Setup EVM-native NFT for custom cross-VM registration */

    // Deploy the evm-native Cadence NFT contract
    let err = Test.deployContract(
            name: "ExampleEVMNativeNFTGivenEVMAddress",
            path: "../contracts/example-assets/cross-vm-nfts/ExampleEVMNativeNFTGivenEVMAddress.cdc",
            arguments: [proxyAddressHex] // NOTE: set the proxy address as the associated EVM address
        )
    Test.expect(err, Test.beNil())
    customNFTIdentifier = Type<@ExampleEVMNativeNFTGivenEVMAddress.NFT>().identifier
    upgradeERC721()

    /* Register custom cross-VM association */

    // Now register the updated ExampleNFT as cross-VM, associating the deployed ERC721
    registerCrossVMNFT(
        signer: erc721Account,
        nftTypeIdentifier: customNFTIdentifier,
        fulfillmentMinterPath: ExampleEVMNativeNFTGivenEVMAddress.FulfillmentMinterStoragePath,
        beFailed: false
    )

    // Move the bridged NFT to EVM - should move as original ERC721 & the NFT should be burned
    // since the Cadence association has been updated
    bridgeNFTToEVM(
        signer: user,
        nftIdentifier: bridgedNFTIdentifier,
        nftID: bridgedNFTID,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )
    var evts = Test.eventsOfType(Type<NonFungibleToken.NFT.ResourceDestroyed>())
    Test.assertEqual(1, evts.length)
    let destroyedEvt = evts[0] as! NonFungibleToken.NFT.ResourceDestroyed
    Test.assertEqual(bridgedNFTID, destroyedEvt.id)

    evts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTToEVM>())
    Test.assertEqual(1, evts.length)
    let bridgedEvt = evts[0] as! IFlowEVMNFTBridge.BridgedNFTToEVM
    Test.assertEqual(bridgedNFTID, bridgedEvt.id)
    Test.assertEqual(erc721ID, bridgedEvt.evmID)
    Test.assertEqual(userCOAHex, bridgedEvt.to)
    Test.assertEqual("0x\(proxyAddressHex)", "0x\(bridgedEvt.evmContractAddress)")

    // assert ERC721 is in escrow under bridge COA
    let userIsOwner = isOwner(of: erc721ID, ownerEVMAddrHex: userCOAHex, erc721AddressHex: proxyAddressHex)
    Test.assert(userIsOwner, message: "ERC721 \(erc721ID) was not bridged to user after bridging to EVM")

    // ensure Cadence NFT is escrowed
    let isLocked = isNFTLocked(nftTypeIdentifier: customNFTIdentifier, id: UInt64(erc721ID))
    Test.assert(!isLocked, message: "Bridged NFT was found in bridge escrow, but it should have been burned")
}

access(all)
fun testMigrateBridgedNFTAfterUpdatingSucceeds() {
    Test.reset(to: snapshot)

    let user = Test.createAccount()
    setupAccount(user, flowAmount: 10.0, coaAmount: 1.0)
    let userCOAHex = getCOAAddressHex(atFlowAddress: user.address)

    // Cadence-native permissionless onboarding
    onboardByEVMAddress(signer: user, evmAddressHex: proxyAddressHex, beFailed: false)
    // Assign the bridged NFT type after onboarding
    bridgedNFTIdentifier = getTypeAssociated(with: proxyAddressHex)

    /* Mint the ERC721 & Bridge from EVM as Bridged NFT */

    let mintCalldata = EVM.encodeABIWithSignature("safeMint(address,uint256)", [EVM.addressFromString(userCOAHex), erc721ID])
    let mintRes = executeTransaction(
        "../transactions/evm/call.cdc",
        [proxyAddressHex, String.encodeHex(mintCalldata), UInt64(15_000_000), UInt(0)],
        erc721Account
    )
    Test.expect(mintRes, Test.beSucceeded())

    bridgeNFTFromEVM(
        signer: user,
        nftIdentifier: bridgedNFTIdentifier,
        erc721ID: erc721ID,
        bridgeAccountAddr: bridgeAccount.address,
        beFailed: false
    )

    // get the bridged NFT ID
    let derivedERC721ContractName = deriveBridgedNFTContractName(evmAddressHex: proxyAddressHex)
    let bridgedCollectionPathIdentifier = derivedERC721ContractName.concat("Collection")
    var ids = getIDs(ownerAddr: user.address, storagePathIdentifier: bridgedCollectionPathIdentifier)
    Test.assertEqual(1, ids.length)
    let bridgedNFTID = ids[0]

    /* Setup EVM-native NFT for custom cross-VM registration */

    // Deploy the evm-native Cadence NFT contract
    let err = Test.deployContract(
            name: "ExampleEVMNativeNFTGivenEVMAddress",
            path: "../contracts/example-assets/cross-vm-nfts/ExampleEVMNativeNFTGivenEVMAddress.cdc",
            arguments: [proxyAddressHex] // NOTE: set the proxy address as the associated EVM address
        )
    Test.expect(err, Test.beNil())
    customNFTIdentifier = Type<@ExampleEVMNativeNFTGivenEVMAddress.NFT>().identifier
    upgradeERC721()

    /* Register custom cross-VM association */

    // Now register the updated ExampleNFT as cross-VM, associating the deployed ERC721
    registerCrossVMNFT(
        signer: erc721Account,
        nftTypeIdentifier: customNFTIdentifier,
        fulfillmentMinterPath: ExampleEVMNativeNFTGivenEVMAddress.FulfillmentMinterStoragePath,
        beFailed: false
    )

    // Move the bridged NFT to EVM and back - should end with the updated custom Cadence NFT since the  Cadence
    // association has been updated
    let migrateRes = executeTransaction(
        "../transactions/bridge/nft/batch_migrate_bridged_cadence_nft.cdc",
        [bridgedNFTIdentifier, [bridgedNFTID]],
        user
    )
    Test.expect(migrateRes, Test.beSucceeded())

    let evts = Test.eventsOfType(Type<IFlowEVMNFTBridge.BridgedNFTFromEVM>())
    Test.assertEqual(2, evts.length)
    let bridgedEvt = evts[evts.length - 1] as! IFlowEVMNFTBridge.BridgedNFTFromEVM
    Test.assertEqual(UInt64(erc721ID), bridgedEvt.id)
    Test.assertEqual(erc721ID, bridgedEvt.evmID)
    Test.assertEqual(userCOAHex, bridgedEvt.caller)
    Test.assertEqual("0x\(proxyAddressHex)", "0x\(bridgedEvt.evmContractAddress)")

    // assert ERC721 is in escrow under bridge COA
    let erc721IsEscrowed = isOwner(of: erc721ID, ownerEVMAddrHex: getBridgeCOAAddressHex(), erc721AddressHex: proxyAddressHex)
    Test.assert(erc721IsEscrowed, message: "ERC721 \(erc721ID) was bridged from EVM but the token was not found in escrow")

    // ensure user has Cadence NFT
    ids = getIDs(ownerAddr: user.address, storagePathIdentifier: "ExampleEVMNativeNFTCollection")
    Test.assertEqual(1, ids.length)
    Test.assertEqual(UInt64(erc721ID), ids[0])
}

/* --- Case-Specific Helpers --- */

access(all)
fun setupAccount(_ user: Test.TestAccount, flowAmount: UFix64, coaAmount: UFix64) {
    // fund account
    transferFlow(signer: serviceAccount, recipient: user.address, amount: flowAmount)
    // create COA in account
    createCOA(signer: user, fundingAmount: coaAmount)
}

access(all)
fun upgradeERC721() {
    // Update the ERC721 implementation with a cross-VM compatible EVM deployment
    let v2DeploymentResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [getEVMNativeERC721UpgradableV2Bytecode(), UInt64(15_000_000), 0.0],
        erc721Account
    )
    Test.expect(v2DeploymentResult, Test.beSucceeded())
    // Assign the v2 implementation address
    var evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    erc721AddressHex = getEVMAddressHexFromEvents(evts, idx: evts.length - 1)

    // Construct the upgradeToAndCall calldata
    let initializeBytes = EVM.EVMBytes(value: EVM.encodeABIWithSignature(
            "initializeV2(string,string)",
            [erc721Account.address.toString(), customNFTIdentifier]
        ))
    let calldata = EVM.encodeABIWithSignature(
            "upgradeToAndCall(address,bytes)",
            [EVM.addressFromString(erc721AddressHex), initializeBytes]
        )
    // deploy the ERC1967Proxy contract
    let upgradeResult = executeTransaction(
        "../transactions/evm/call.cdc",
        [proxyAddressHex, String.encodeHex(calldata), UInt64(15_000_000), UInt(0)],
        erc721Account
    )
    Test.expect(upgradeResult, Test.beSucceeded())
}