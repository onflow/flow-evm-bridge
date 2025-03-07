import Test
import BlockchainHelpers

import "MetadataViews"
import "EVM"
import "ExampleEVMNativeNFT"

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
    // TEMPORARY: Only included until emulator auto-deploys CrossVMMetadataViews
    var err = Test.deployContract(
        name: "CrossVMMetadataViews",
        path: "../../imports/631e88ae7f1d7c20/CrossVMMetadataViews.cdc",
        arguments: []
    )
    // Deploy supporting util contracts
    err = Test.deployContract(
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
        name: "FlowEVMBridgeCustomAssociationTypes",
        path: "../contracts/bridge/FlowEVMBridgeCustomAssociationTypes.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeCustomAssociations",
        path: "../contracts/bridge/FlowEVMBridgeCustomAssociations.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "FlowEVMBridgeConfig",
        path: "../contracts/bridge/FlowEVMBridgeConfig.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

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
    transferFlow(signer: serviceAccount, recipient: exampleEVMNativeNFTAccount.address, amount: 1_000.0)

    err = Test.deployContract(
        name: "ExampleEVMNativeNFT",
        path: "../contracts/example-assets/cross-vm-nfts/ExampleEVMNativeNFT.cdc",
        arguments: [getEVMNativeERC721Bytecode()]
    )
    Test.expect(err, Test.beNil())
    erc721AddressHex = ExampleEVMNativeNFT.getEVMContractAddress().toString()

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

    // Unpause the bridge
    updateBridgePauseStatus(signer: bridgeAccount, pause: false)
}

access(all)
fun testRegisterCrossVMNFTSucceeds() {
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