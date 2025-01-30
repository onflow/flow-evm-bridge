package bridge

import (
	"embed"
	"fmt"
	"log"
	"strings"

	coreContracts "github.com/onflow/flow-core-contracts/lib/go/templates"
)

//go:embed cadence/contracts/bridge/interfaces/CrossVMNFT.cdc
var content embed.FS

var (
	placeholderFungibleTokenAddress   = "\"FungibleToken\""
	placeholderFungibleTokenMVAddress = "\"FungibleTokenMetadataViews\""
	placeholderMetadataViewsAddress   = "\"MetadataViews\""
	placeholderFlowTokenAddress       = "\"FlowToken\""
	placeholderBurnerAddress          = "\"Burner\""
	placeholderViewResolverAddress    = "\"ViewResolver\""
	placeholderNFTAddress             = "\"NonFungibleToken\""

	placeholderCrossVMNFTAddress                     = "\"CrossVMNFT\""
	placeholderCrossVMTokenAddress                   = "\"CrossVMToken\""
	placeholderFlowEVMBridgeHandlerInterfacesAddress = "\"FlowEVMBridgeHandlerInterfaces\""
	placeholderIBridgePermissionsAddress             = "\"IBridgePermissions\""
	placeholderICrossVMAddress                       = "\"ICrossVM\""
	placeholderICrossVMAssetAddress                  = "\"ICrossVMAsset\""
	placeholderIEVMBridgeNFTMinterAddress            = "\"IEVMBridgeNFTMinter\""
	placeholderIEVMBridgeTokenMinterAddress          = "\"IEVMBridgeTokenMinter\""
	placeholderIFlowEVMNFTBridgeAddress              = "\"IFlowEVMNFTBridge\""
	placeholderIFlowEVMTokenBridgeAddress            = "\"IFlowEVMTokenBridge\""
	placeholderFlowEVMBridgeAddress                  = "\"FlowEVMBridge\""
	placeholderFlowEVMBridgeAccessorAddress          = "\"FlowEVMBridgeAccessor\""
	placeholderFlowEVMBridgeConfigAddress            = "\"FlowEVMBridgeConfig\""
	placeholderFlowEVMBridgeHandlersAddress          = "\"FlowEVMBridgeHandlers\""
	placeholderFlowEVMBridgeNFTEscrowAddress         = "\"FlowEVMBridgeNFTEscrow\""
	placeholderFlowEVMBridgeResolverAddress          = "\"FlowEVMBridgeResolver\""
	placeholderFlowEVMBridgeTemplatesAddress         = "\"FlowEVMBridgeTemplates\""
	placeholderFlowEVMBridgeTokenEscrowAddress       = "\"FlowEVMBridgeTokenEscrow\""
	placeholderFlowEVMBridgeUtilsAddress             = "\"FlowEVMBridgeUtils\""

	placeholderArrayUtilsAddress        = "\"ArrayUtils\""
	placeholderScopedFTProvidersAddress = "\"ScopedFTProviders\""
	placeholderSerializeAddress         = "\"Serialize\""
	placeholderSerializeMetadataAddress = "\"SerializeMetadata\""
	placeholderStringUtilsAddress       = "\"StringUtils\""
)

type Environment struct {
	CrossVMNFTAddress                     string
	CrossVMTokenAddress                   string
	FlowEVMBridgeHandlerInterfacesAddress string
	IBridgePermissionsAddress             string
	ICrossVMAddress                       string
	ICrossVMAssetAddress                  string
	IEVMBridgeNFTMinterAddress            string
	IEVMBridgeTokenMinterAddress          string
	IFlowEVMNFTBridgeAddress              string
	IFlowEVMTokenBridgeAddress            string
	FlowEVMBridgeAddress                  string
	FlowEVMBridgeAccessorAddress          string
	FlowEVMBridgeConfigAddress            string
	FlowEVMBridgeHandlersAddress          string
	FlowEVMBridgeNFTEscrowAddress         string
	FlowEVMBridgeResolverAddress          string
	FlowEVMBridgeTemplatesAddress         string
	FlowEVMBridgeTokenEscrowAddress       string
	FlowEVMBridgeUtilsAddress             string
	ArrayUtilsAddress                     string
	ScopedFTProvidersAddress              string
	SerializeAddress                      string
	SerializeMetadataAddress              string
	StringUtilsAddress                    string
}

func withHexPrefix(address string) string {
	if address == "" {
		return ""
	}

	if address[0:2] == "0x" {
		return address
	}

	return fmt.Sprintf("0x%s", address)
}

func ReplaceAddresses(code string, bridgeEnv Environment, coreEnv coreContracts.Environment) string {

	code = coreContracts.ReplaceAddresses(code, coreEnv)

	code = strings.ReplaceAll(
		code,
		placeholderCrossVMNFTAddress,
		withHexPrefix(bridgeEnv.CrossVMNFTAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderCrossVMTokenAddress,
		withHexPrefix(bridgeEnv.CrossVMTokenAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeHandlerInterfacesAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeHandlerInterfacesAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderIBridgePermissionsAddress,
		withHexPrefix(bridgeEnv.IBridgePermissionsAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderICrossVMAddress,
		withHexPrefix(bridgeEnv.ICrossVMAddress),
	)
	code = strings.ReplaceAll(
		code,
		placeholderICrossVMAssetAddress,
		withHexPrefix(bridgeEnv.ICrossVMAssetAddress),
	)
	code = strings.ReplaceAll(
		code,
		placeholderIEVMBridgeNFTMinterAddress,
		withHexPrefix(bridgeEnv.IEVMBridgeNFTMinterAddress),
	)
	code = strings.ReplaceAll(
		code,
		placeholderIEVMBridgeTokenMinterAddress,
		withHexPrefix(bridgeEnv.IEVMBridgeTokenMinterAddress),
	)
	code = strings.ReplaceAll(
		code,
		placeholderIFlowEVMNFTBridgeAddress,
		withHexPrefix(bridgeEnv.IFlowEVMNFTBridgeAddress),
	)
	code = strings.ReplaceAll(
		code,
		placeholderIFlowEVMTokenBridgeAddress,
		withHexPrefix(bridgeEnv.IFlowEVMTokenBridgeAddress),
	)
	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeAddress),
	)
	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeAccessorAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeAccessorAddress),
	)
	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeConfigAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeConfigAddress),
	)
	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeHandlersAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeHandlersAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeNFTEscrowAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeNFTEscrowAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeResolverAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeResolverAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeTemplatesAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeTemplatesAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeTokenEscrowAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeTokenEscrowAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderFlowEVMBridgeUtilsAddress,
		withHexPrefix(bridgeEnv.FlowEVMBridgeUtilsAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderArrayUtilsAddress,
		withHexPrefix(bridgeEnv.ArrayUtilsAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderScopedFTProvidersAddress,
		withHexPrefix(bridgeEnv.ScopedFTProvidersAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderSerializeAddress,
		withHexPrefix(bridgeEnv.SerializeAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderSerializeMetadataAddress,
		withHexPrefix(bridgeEnv.SerializeMetadataAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderStringUtilsAddress,
		withHexPrefix(bridgeEnv.StringUtilsAddress),
	)

	return code
}

func GetCadenceCode(contractPath string, bridgeEnv Environment, coreEnv coreContracts.Environment) []byte {

	fileContent, err := content.ReadFile(contractPath)

	if err != nil {
		log.Fatal(err)
	}

	// Convert []byte to string
	code := string(fileContent)

	code = ReplaceAddresses(code, bridgeEnv, coreEnv)

	if strings.Contains(code, "import \"") {
		log.Fatal("Missing import addresses for one or more contracts in the import list!")
	}

	return []byte(code)
}

/**
 * This script is used to configure the bridge contracts on various networks.
 * The following assumptions about the bridge account are made:
 * - The bridge account is named "NETWORK-flow-evm-bridge" in the flow.json
 * - The bridge account has a balance to cover funding a COA with 1.0 FLOW tokens (if necessary)
 * - The bridge account has enough FLOW to cover the storage required for the deployed contracts
 */

// Overflow prefixes signer names with the current network - e.g. "crescendo-flow-evm-bridge"
// Ensure accounts in flow.json are named accordingly
// var networks = []string{"crescendo", "emulator", "mainnet", "previewnet", "testnet"}

// // Pulled from flow.json deployments. Specified here as some contracts have init arg values that
// // are emitted in transaction events and cannot be hardcoded in the deployment config section
// var contracts = []string{
// 	"FlowEVMBridgeHandlerInterfaces",
// 	"ArrayUtils",
// 	"StringUtils",
// 	"ScopedFTProviders",
// 	"Serialize",
// 	"SerializeMetadata",
// 	"IBridgePermissions",
// 	"ICrossVM",
// 	"ICrossVMAsset",
// 	"CrossVMNFT",
// 	"CrossVMToken",
// 	"FlowEVMBridgeConfig",
// 	"FlowEVMBridgeUtils",
// 	"FlowEVMBridgeResolver",
// 	"FlowEVMBridgeHandlers",
// 	"FlowEVMBridgeNFTEscrow",
// 	"FlowEVMBridgeTokenEscrow",
// 	"FlowEVMBridgeTemplates",
// 	"IEVMBridgeNFTMinter",
// 	"IEVMBridgeTokenMinter",
// 	"IFlowEVMNFTBridge",
// 	"IFlowEVMTokenBridge",
// 	"FlowEVMBridge",
// }

// // To run, execute the following command:
// // go run main.go $NETWORK
// func main() {
// 	network := getSpecifiedNetwork()

// 	dir, err := os.Getwd()
// 	checkNoErr(err)

// 	ctx := context.Background()
// 	o := Overflow(
// 		WithNetwork(network),
// 		WithTransactionFolderName("cadence/transactions"),
// 		WithScriptFolderName("cadence/scripts"),
// 		WithGlobalPrintOptions(WithTransactionUrl()),
// 	)

// 	// Check if the script is a dry run
// 	if checkDryRun() {
// 		log.Printf("Dry run detected...running setup script in dry run mode")
// 		// Run the dry run transaction
// 		serviceDryRunResult := o.Tx("bridge/admin/dry_run", WithSigner("service-account"))
// 		checkNoErr(serviceDryRunResult.Err)
// 		log.Printf("Service Account dry run run successful...")
// 		bridgeDryRunResult := o.Tx("bridge/admin/dry_run", WithSigner("flow-evm-bridge"))
// 		checkNoErr(bridgeDryRunResult.Err)
// 		log.Printf("Bridge Account dry run run successful...")
// 		log.Printf("Dry run complete...exiting script")
// 		return
// 	}

// 	// Create a COA in the bridge account if one does not already exist
// 	bridgeCOAHex, err := o.Script("evm/get_evm_address_string", WithArg("flowAddress", o.Address("flow-evm-bridge"))).GetAsInterface()
// 	checkNoErr(err)
// 	if bridgeCOAHex == nil {
// 		// no COA found, create a COA in the bridge account
// 		coaCreationTxn := o.Tx("evm/create_account", WithSigner("flow-evm-bridge"), WithArg("amount", 1.0))
// 		checkNoErr(coaCreationTxn.Err)
// 		bridgeCOAHex, err = o.Script("evm/get_evm_address_string", WithArg("flowAddress", o.Address("flow-evm-bridge"))).GetAsInterface()
// 		checkNoErr(err)
// 	}
// 	log.Printf("Bridge COA has EVM address: %s", bridgeCOAHex)

// 	/* --- EVM Configuration --- */

// 	gasLimit := 15000000
// 	deploymentValue := 0.0

// 	/// Deploy factory ///
// 	//
// 	// Get the Cadence args json for the factory deployment args
// 	factoryArgsPath := filepath.Join(dir, "cadence/args/deploy-factory-args.json")
// 	// Retrieve the bytecode from the JSON args
// 	// Future implementations should use flowkit to handle this after fixing dependency issues
// 	factoryBytecode := getBytecodeFromArgsJSON(factoryArgsPath)
// 	factoryDeployment := o.Tx("evm/deploy",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("bytecode", factoryBytecode),
// 		WithArg("gasLimit", gasLimit),
// 		WithArg("value", deploymentValue),
// 	)
// 	checkNoErr(factoryDeployment.Err)
// 	factoryAddr := getContractAddressFromEVMEvent(factoryDeployment)

// 	log.Printf("Factory deployed to address: %s", factoryAddr)

// 	/// Deploy registry ///
// 	//
// 	// Get the Cadence args json for the factory deployment args
// 	registryArgsPath := filepath.Join(dir, "cadence/args/deploy-deployment-registry-args.json")
// 	// Retrieve the bytecode from the JSON args
// 	// Future implementations should use flowkit to handle this after fixing dependency issues
// 	registryBytecode := getBytecodeFromArgsJSON(registryArgsPath)
// 	registryDeployment := o.Tx("evm/deploy",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("bytecode", registryBytecode),
// 		WithArg("gasLimit", gasLimit),
// 		WithArg("value", deploymentValue),
// 	)
// 	checkNoErr(registryDeployment.Err)
// 	registryAddr := getContractAddressFromEVMEvent(registryDeployment)

// 	log.Printf("Registry deployed to address: %s", registryAddr)

// 	/// Deploy ERC20 deployer ///
// 	//
// 	erc20DeployerArgsPath := filepath.Join(dir, "cadence/args/deploy-erc20-deployer-args.json")
// 	erc20DeployerBytecode := getBytecodeFromArgsJSON(erc20DeployerArgsPath)
// 	erc20DeployerDeployment := o.Tx("evm/deploy",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("bytecode", erc20DeployerBytecode),
// 		WithArg("gasLimit", gasLimit),
// 		WithArg("value", deploymentValue),
// 	)
// 	checkNoErr(erc20DeployerDeployment.Err)
// 	erc20DeployerAddr := getContractAddressFromEVMEvent(erc20DeployerDeployment)

// 	log.Printf("ERC20 Deployer deployed to address: %s", erc20DeployerAddr)

// 	/// Deploy ERC721 deployer ///
// 	//
// 	erc721DeployerArgsPath := filepath.Join(dir, "cadence/args/deploy-erc721-deployer-args.json")
// 	erc721DeployerBytecode := getBytecodeFromArgsJSON(erc721DeployerArgsPath)
// 	erc721DeployerDeployment := o.Tx("evm/deploy",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("bytecode", erc721DeployerBytecode),
// 		WithArg("gasLimit", gasLimit),
// 		WithArg("value", deploymentValue),
// 	)
// 	checkNoErr(erc721DeployerDeployment.Err)
// 	erc721DeployerAddr := getContractAddressFromEVMEvent(erc721DeployerDeployment)

// 	log.Printf("ERC721 Deployer deployed to address: %s", erc721DeployerAddr)

// 	/* --- Cadence Configuration --- */

// 	log.Printf("Deploying Cadence contracts...")
// 	// Iterate over contracts in the contracts map
// 	for _, name := range contracts {

// 		log.Printf("Deploying contract: %s...", name)

// 		contract, err := o.State.Config().Contracts.ByName(name)
// 		checkNoErr(err)
// 		contractPath := filepath.Join(dir, contract.Location)
// 		contractCode, err := os.ReadFile(contractPath)
// 		checkNoErr(err)

// 		// If the contract is already deployed as-is, skip deployment
// 		a, err := o.GetAccount(ctx, "flow-evm-bridge")
// 		checkNoErr(err)
// 		log.Printf("Checking if contract %s is already deployed...", name)
// 		if a.Contracts[name] != nil {
// 			log.Printf("Contract %s already deployed, skipping...", name)
// 			continue
// 		}
// 		log.Printf("Contract %s not found on %s, deploying...", name, network)

// 		var args []cadence.Value
// 		if name == "FlowEVMBridgeUtils" {
// 			args = []cadence.Value{cadence.String(factoryAddr)}
// 		} else {
// 			args = []cadence.Value{}
// 		}

// 		err = o.AddContract(ctx, "flow-evm-bridge", contractCode, args, contractPath, true)
// 		checkNoErr(err)
// 	}
// 	log.Printf("Cadence contracts deployed...Pausing bridge for setup...")

// 	// If emulator, deploy USDCFlow contract
// 	if network == "emulator" {
// 		log.Printf("Emulator detected...deploying USDCFlow contract...")

// 		usdcContract, err := o.State.Config().Contracts.ByName("USDCFlow")
// 		checkNoErr(err)

// 		usdcPath := filepath.Join(dir, usdcContract.Location)
// 		usdcCode, err := os.ReadFile(usdcPath)
// 		checkNoErr(err)

// 		err = o.AddContract(ctx, "flow-evm-bridge", usdcCode, []cadence.Value{}, usdcPath, true)
// 		checkNoErr(err)

// 		log.Printf("USDCFlow contract deployed...")
// 	}

// 	// Pause the bridge for setup
// 	var pauseResult = o.Tx("bridge/admin/pause/update_bridge_pause_status",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("pause", true),
// 	)
// 	checkNoErr(pauseResult.Err)

// 	log.Printf("Bridge deployed and paused...")

// 	/* --- USDCFlow TokenHandler Configuration --- */

// 	// Add USDCFlow TokenHandler
// 	// usdcFlowAddr := o.Address("USDCFlow")
// 	// usdcFlowVaultIdentifier := buildUSDCFlowVaultIdentifier(usdcFlowAddr)
// 	// usdcFlowMinterIdentifier := buildUSDCFlowMinterIdentifier(usdcFlowAddr)

// 	// log.Printf("Bridge pause confirmed...configuring USDCFlow TokenHandler with vault=" + usdcFlowVaultIdentifier + " and minter=" + usdcFlowMinterIdentifier)

// 	// // execute create_cadence_native_token_handler transaction
// 	// createTokenHandlerResult := o.Tx("bridge/admin/token-handler/create_cadence_native_token_handler",
// 	// 	WithSigner("flow-evm-bridge"),
// 	// 	WithArg("vaultIdentifier", usdcFlowVaultIdentifier),
// 	// 	WithArg("minterIdentifier", usdcFlowMinterIdentifier),
// 	// )
// 	// checkNoErr(createTokenHandlerResult.Err)

// 	// log.Printf("USDCFlow TokenHandler configured...")

// 	/* --- Finish EVM Contract Setup --- */

// 	log.Printf("Integrating EVM-side bridge contracts...")

// 	// Set the factory as registrar in the registry
// 	setRegistrarResult := o.Tx("bridge/admin/evm/set_registrar",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("registryEVMAddressHex", registryAddr),
// 	)
// 	checkNoErr(setRegistrarResult.Err)
// 	// Add the registry to the factory
// 	setRegistryResult := o.Tx("bridge/admin/evm/set_deployment_registry",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("registryEVMAddressHex", registryAddr),
// 	)
// 	checkNoErr(setRegistryResult.Err)

// 	// Set the factory as delegated deployer in the ERC20 deployer
// 	setDelegatedDeployerResult := o.Tx("bridge/admin/evm/set_delegated_deployer",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("deployerEVMAddressHex", erc20DeployerAddr),
// 	)
// 	checkNoErr(setDelegatedDeployerResult.Err)

// 	// Set the factory as delegated deployer in the ERC721 deployer
// 	setDelegatedDeployerResult = o.Tx("bridge/admin/evm/set_delegated_deployer",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("deployerEVMAddressHex", erc721DeployerAddr),
// 	)
// 	checkNoErr(setDelegatedDeployerResult.Err)

// 	// Add the ERC20 Deployer as a deployer in the factory
// 	addDeployerResult := o.Tx("bridge/admin/evm/add_deployer",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("deployerTag", "ERC20"),
// 		WithArg("deployerEVMAddressHex", erc20DeployerAddr),
// 	)
// 	checkNoErr(addDeployerResult.Err)

// 	// Add the ERC721 Deployer as a deployer in the factory
// 	addDeployerResult = o.Tx("bridge/admin/evm/add_deployer",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("deployerTag", "ERC721"),
// 		WithArg("deployerEVMAddressHex", erc721DeployerAddr),
// 	)
// 	checkNoErr(addDeployerResult.Err)

// 	log.Printf("Cross-VM bridge contract integration complete...integrating with EVM contract...")

// 	/* --- EVM Contract Integration --- */

// 	// Deploy FlowEVMBridgeAccessor, providing EVM contract host (network service account) as argument
// 	accessorContract, err := o.State.Config().Contracts.ByName("FlowEVMBridgeAccessor")
// 	checkNoErr(err)
// 	// accessorPath := filepath.Join(projectRoot, accessorContract.Location)
// 	accessorPath := filepath.Join(dir, accessorContract.Location)
// 	accessorCode, err := os.ReadFile(accessorPath)
// 	checkNoErr(err)
// 	evmConfigAddr, err := o.State.Config().Contracts.ByName("EVM")
// 	checkNoErr(err)
// 	evmAddr := evmConfigAddr.Aliases.ByNetwork(o.GetNetwork()).Address
// 	log.Printf("EVM contract address: %s", evmAddr)
// 	err = o.AddContract(ctx, "flow-evm-bridge", accessorCode, []cadence.Value{cadence.NewAddress(evmAddr)}, accessorPath, false)
// 	checkNoErr(err)

// 	// Integrate the EVM contract with the BridgeAccessor
// 	integrateResult := o.Tx("bridge/admin/evm-integration/claim_accessor_capability_and_save_router",
// 		WithSigner("service-account"),
// 		WithArg("name", "FlowEVMBridgeAccessor"),
// 		WithArg("provider", o.Address("FlowEVMBridge")),
// 	)
// 	checkNoErr(integrateResult.Err)

// 	log.Printf("EVM integration complete...setting fees...")

// 	/* --- Set Bridge Fees --- */

// 	onboardFeeResult := o.Tx("bridge/admin/fee/update_onboard_fee",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("newFee", 1.0),
// 	)
// 	checkNoErr(onboardFeeResult.Err)
// 	baseFeeResult := o.Tx("bridge/admin/fee/update_base_fee",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("newFee", 0.001),
// 	)
// 	checkNoErr(baseFeeResult.Err)

// 	/* --- COMPLETE --- */

// 	log.Printf("Bridge setup complete...Adding bridged Token & NFT templates")

// 	// TODO: Try to pull args JSON from local file once flowkit ParseJSON is fixed
// 	tokenChunkPath := filepath.Join(
// 		dir,
// 		"cadence/args/bridged-token-code-chunks-args-"+network+".json",
// 	)
// 	nftChunkPath := filepath.Join(dir, "cadence/args/bridged-nft-code-chunks-args-"+network+".json")
// 	tokenChunks := getCodeChunksFromArgsJSON(tokenChunkPath)
// 	nftChunks := getCodeChunksFromArgsJSON(nftChunkPath)
// 	tokenChunkUpsert := o.Tx("bridge/admin/templates/upsert_contract_code_chunks",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("forTemplate", "bridgedToken"),
// 		WithArg("newChunks", tokenChunks),
// 	)
// 	checkNoErr(tokenChunkUpsert.Err)
// 	nftChunkUpsert := o.Tx("bridge/admin/templates/upsert_contract_code_chunks",
// 		WithSigner("flow-evm-bridge"),
// 		WithArg("forTemplate", "bridgedNFT"),
// 		WithArg("newChunks", nftChunks),
// 	)
// 	checkNoErr(nftChunkUpsert.Err)

// 	log.Printf("Templates have been added...Unpausing bridge...")

// 	// Unpause the bridge
// 	// unpauseResult := o.Tx("bridge/admin/pause/update_bridge_pause_status",
// 	// 	WithSigner("flow-evm-bridge"),
// 	// 	WithArg("pause", false),
// 	// )
// 	// checkNoErr(unpauseResult.Err)

// 	// log.Printf("SETUP COMPLETE! Bridge is now unpaused and ready for use.")
// 	log.Printf("SETUP COMPLETE! Bridge is still paused - be sure to unpause before use.")
// }

// func checkDryRun() bool {
// 	if len(os.Args) < 3 {
// 		return false
// 	}
// 	return os.Args[2] == "--dry-run"
// }

// // Parses the network argument from the command line
// // e.g. go run main.go $NETWORK
// func getSpecifiedNetwork() string {
// 	if len(os.Args) < 2 {
// 		log.Fatal("Please provide a network as an argument: ", networks)
// 	}
// 	network := os.Args[1]

// 	if !slices.Contains(networks, network) {
// 		log.Fatal("Please provide a valid network as an argument: ", networks)
// 	}
// 	return network
// }

// // Extracts the deployed contract address from the TransactionExecuted event
// func getContractAddressFromEVMEvent(res *OverflowResult) string {
// 	evts := res.GetEventsWithName("TransactionExecuted")
// 	contractAddr := evts[0].Fields["contractAddress"]
// 	if contractAddr == nil {
// 		log.Fatal("Contract address not found in event")
// 	}
// 	return strings.ToLower(strings.Split(contractAddr.(string), "x")[1])
// }

// // Reads the JSON file at the specified path and returns the compiled solidity bytecode where the
// // bytecode is the first element in the JSON array as a Cadence JSON string
// func getBytecodeFromArgsJSON(path string) string {
// 	argsData, err := os.ReadFile(path)
// 	checkNoErr(err)

// 	var args []map[string]string

// 	err = json.Unmarshal(argsData, &args)
// 	checkNoErr(err)

// 	return args[0]["value"]
// }

// type Element struct {
// 	Type  string      `json:"type"`
// 	Value interface{} `json:"value"`
// }

// // Reads the JSON file at the specified path and returns the code chunks where the code chunks are
// // the second element in the JSON array as Cadence JSON string array
// func getCodeChunksFromArgsJSON(path string) []string {
// 	file, err := os.Open(path)
// 	if err != nil {
// 		log.Fatalf("Failed opening file: %s", err)
// 	}
// 	defer file.Close()

// 	byteValue, _ := ioutil.ReadAll(file)

// 	var elements []Element
// 	json.Unmarshal(byteValue, &elements)

// 	secondElement := elements[1]

// 	// Check if the second element is of type "Array"
// 	if secondElement.Type != "Array" {
// 		log.Fatalf("Second element is not of type Array")
// 	}

// 	// Assert that the value is a slice of interfaces
// 	values, ok := secondElement.Value.([]interface{})
// 	if !ok {
// 		log.Fatalf("Failed to assert value to []interface{}")
// 	}

// 	var strArr []string
// 	for _, v := range values {
// 		// Assert that the value is a map
// 		valueMap, ok := v.(map[string]interface{})
// 		if !ok {
// 			log.Fatalf("Failed to assert value to map[string]interface{}")
// 		}

// 		// Get the "value" from the map and assert it to string
// 		str, ok := valueMap["value"].(string)
// 		if !ok {
// 			log.Fatalf("Failed to assert value to string")
// 		}

// 		strArr = append(strArr, str)
// 	}

// 	return strArr
// }

// func buildUSDCFlowVaultIdentifier(addrString string) string {
// 	return "A." + strings.Split(addrString, "x")[1] + ".USDCFlow.Vault"
// }

// func buildUSDCFlowMinterIdentifier(addrString string) string {
// 	return "A." + strings.Split(addrString, "x")[1] + ".USDCFlow.Minter"
// }

// func checkNoErr(err error) {
// 	if err != nil {
// 		log.Fatal(err)
// 	}
// }
