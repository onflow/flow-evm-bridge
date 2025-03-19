import Test
import BlockchainHelpers

import "MetadataViews"
import "EVM"
import "ExampleNFT"
import "FlowEVMBridge"
import "FlowEVMBridgeUtils"
import "FlowEVMBridgeCustomAssociations"

import "test_helpers.cdc"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let bridgeAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let alice = Test.createAccount()
access(all) let bob = Test.createAccount()

// ExampleNFT
access(all) let exampleNFTIdentifier = "A.0000000000000008.ExampleNFT.NFT"
access(all) var mintedNFTID: UInt64 = 0

// Bridge-related EVM contract values
access(all) var registryAddressHex: String = ""
access(all) var erc20DeployerAddressHex: String = ""
access(all) var erc721DeployerAddressHex: String = ""

// ERC721 values
access(all) var bridgedERC721AddressHex: String = ""
access(all) var customERC721AddressHex: String = ""
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
fun testOnboardExampleNFTSucceeds() {
    var typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(true, typeRequiresOnboarding)

    // Cadence-native onboarding
    let onboardingResult = executeTransaction(
        "../transactions/bridge/onboarding/onboard_by_type_identifier.cdc",
        [exampleNFTIdentifier],
        alice
    )
    Test.expect(onboardingResult, Test.beSucceeded())

    typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, typeRequiresOnboarding)

    let evts = Test.eventsOfType(Type<FlowEVMBridge.Onboarded>())
    Test.assertEqual(1, evts.length)
    let onboardedEvt = evts[0] as! FlowEVMBridge.Onboarded
    Test.assertEqual(exampleNFTIdentifier, onboardedEvt.type)

    bridgedERC721AddressHex = onboardedEvt.evmContractAddress
    Test.assertEqual(getAssociatedEVMAddressHex(with: exampleNFTIdentifier), bridgedERC721AddressHex)
}

access(all)
fun testUpdateToCustomAssociationSucceeds() {
    // Previously onboarded with a bridged ERC721 representation in EVM
    var typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, typeRequiresOnboarding)

    // Create a COA in exampleNFT account
    createCOA(signer: exampleNFTAccount, fundingAmount: 0.0)
    // Deploy the cadence native ERC721
    let encodedArgs = EVM.encodeABI([
        "ExampleNFT",
        "XMPL",
        exampleNFTAccount.address.toString(),
        exampleNFTIdentifier,
        EVM.addressFromString(getBridgeCOAAddressHex())
    ])
    let finalBytecode = getCadenceNativeERC721Bytecode().decodeHex().concat(encodedArgs)
    let erc721DeployResult = executeTransaction(
        "../transactions/evm/deploy.cdc",
        [String.encodeHex(finalBytecode), UInt64(15_000_000), 0.0],
        exampleNFTAccount
    )
    Test.expect(erc721DeployResult, Test.beSucceeded())
    // Get the deployed ERC721 address
    var evts = Test.eventsOfType(Type<EVM.TransactionExecuted>())
    let deployedEvt = evts[evts.length - 1] as! EVM.TransactionExecuted
    customERC721AddressHex = deployedEvt.contractAddress

    // Save that deployed address to exampleNFT account storage at /storage/erc721ContractAddress
    let saveAddressResult = executeTransaction(
        "./transactions/save_erc721_address.cdc",
        [customERC721AddressHex],
        exampleNFTAccount
    )
    Test.expect(saveAddressResult, Test.beSucceeded())

    // Update the ExampleNFT contract from hex code
    let updateResult = executeTransaction(
        "./transactions/update_contract.cdc",
        ["ExampleNFT", getExampleNFTAsCrossVMCode()],
        exampleNFTAccount
    )
    Test.expect(updateResult, Test.beSucceeded())

    // Validate onboarding status
    typeRequiresOnboarding = typeRequiresOnboardingByIdentifier(exampleNFTIdentifier)
        ?? panic("Problem getting onboarding requirement by identifier")
    Test.assertEqual(false, typeRequiresOnboarding)

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
