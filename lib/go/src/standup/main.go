package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"slices"
	"strings"

	. "github.com/bjartek/overflow/v2"
	"github.com/onflow/cadence"
)

/**
 * This script is used to configure the bridge contracts on various networks.
 * The following assumptions about the bridge account are made:
 * - The bridge account is named "NETWORK-flow-evm-bridge" in the flow.json
 * - The bridge account has a balance to cover funding a COA with 10.0 FLOW tokens (if necessary)
 * - The bridge account has enough FLOW to cover the storage required for the deployed contracts
 */

var networks = []string{"emulator", "previewnet", "crescendo", "testnet", "mainnet"}

var contracts = []string{
	"FlowEVMBridgeHandlerInterfaces",
	"ArrayUtils",
	"StringUtils",
	"ScopedFTProviders",
	"EVMUtils",
	"Serialize",
	"SerializeMetadata",
	"IBridgePermissions",
	"ICrossVM",
	"CrossVMNFT",
	"CrossVMToken",
	"FlowEVMBridgeConfig",
	"FlowEVMBridgeUtils",
	"FlowEVMBridgeHandlers",
	"FlowEVMBridgeNFTEscrow",
	"FlowEVMBridgeTokenEscrow",
	"FlowEVMBridgeTemplates",
	"IEVMBridgeNFTMinter",
	"IEVMBridgeTokenMinter",
	"IFlowEVMNFTBridge",
	"IFlowEVMTokenBridge",
	"FlowEVMBridge",
}

func main() {
	network := getSpecifiedNetwork()

	// Log the current working directory
	dir, err := os.Getwd()
	checkNoErr(err)
	// Create the filepath for 4 levels up from current working directory as the root of this project
	projectRoot := filepath.Dir(filepath.Dir(filepath.Dir(filepath.Dir((dir)))))
	// Assign flow config path
	flowConfigPath := filepath.Join(projectRoot, "flow.json")
	// Assign Cadence base path as projectRoot/cadence
	root := filepath.Join(projectRoot, "cadence")

	ctx := context.Background()
	o := Overflow(
		WithNetwork(network),
		WithFlowConfig(flowConfigPath),
		WithBasePath(root),
		WithExistingEmulator(),
	)

	// Create a COA in the bridge account if one does not already exist
	bridgeCOAHex, err := o.Script("evm/get_evm_address_string", WithArg("flowAddress", o.Address("flow-evm-bridge"))).GetAsInterface()
	checkNoErr(err)
	if bridgeCOAHex == nil {
		// no COA found, create a COA in the bridge account
		o.Tx("evm/create_account", WithSigner("flow-evm-bridge"), WithArg("amount", 1.0))
		bridgeCOAHex, err = o.Script("evm/get_evm_address_string", WithArg("flowAddress", o.Address("flow-evm-bridge"))).GetAsInterface()
		checkNoErr(err)
	}
	// coaCreated := coaCreation.MarshalEventsWithName("CadenceOwnedAccountCreated", cadence.ConstantSizedArrayType{})
	log.Printf("Bridge COA has EVM address: %s", bridgeCOAHex)

	/* --- EVM Configuration --- */

	gasLimit := 15000000
	deploymentValue := 0.0

	/// Deploy factory ///
	//
	// Get the Cadence args json for the factory deployment args
	factoryArgsPath := filepath.Join(root, "args/deploy-factory-args.json")
	// Retrieve the bytecode from the JSON args
	// Future implementations should use flowkit to handle this after fixing dependency issues
	factoryBytecode := getBytecodeFromArgsJSON(factoryArgsPath)
	factoryDeployment := o.Tx("evm/deploy",
		WithSigner("flow-evm-bridge"),
		WithArg("bytecode", factoryBytecode),
		WithArg("gasLimit", gasLimit),
		WithArg("value", deploymentValue),
	)
	checkNoErr(factoryDeployment.Err)
	factoryAddr := getContractAddressFromEVMEvent(factoryDeployment)

	log.Printf("Factory deployed to address: %s", factoryAddr)

	/// Deploy registry ///
	//
	// Get the Cadence args json for the factory deployment args
	registryArgsPath := filepath.Join(root, "args/deploy-deployment-registry-args.json")
	// Retrieve the bytecode from the JSON args
	// Future implementations should use flowkit to handle this after fixing dependency issues
	registryBytecode := getBytecodeFromArgsJSON(registryArgsPath)
	registryDeployment := o.Tx("evm/deploy",
		WithSigner("flow-evm-bridge"),
		WithArg("bytecode", registryBytecode),
		WithArg("gasLimit", gasLimit),
		WithArg("value", deploymentValue),
	)
	registryAddr := getContractAddressFromEVMEvent(registryDeployment)

	log.Printf("Registry deployed to address: %s", factoryAddr)

	/// Deploy ERC20 deployer ///
	//
	erc20DeployerArgsPath := filepath.Join(root, "args/deploy-erc20-deployer-args.json")
	erc20DeployerBytecode := getBytecodeFromArgsJSON(erc20DeployerArgsPath)
	erc20DeployerDeployment := o.Tx("evm/deploy",
		WithSigner("flow-evm-bridge"),
		WithArg("bytecode", erc20DeployerBytecode),
		WithArg("gasLimit", gasLimit),
		WithArg("value", deploymentValue),
	)
	checkNoErr(erc20DeployerDeployment.Err)
	erc20DeployerAddr := getContractAddressFromEVMEvent(erc20DeployerDeployment)

	log.Printf("ERC20 Deployer deployed to address: %s", factoryAddr)

	/// Deploy ERC721 deployer ///
	//
	erc721DeployerArgsPath := filepath.Join(root, "args/deploy-erc721-deployer-args.json")
	erc721DeployerBytecode := getBytecodeFromArgsJSON(erc721DeployerArgsPath)
	erc721DeployerDeployment := o.Tx("evm/deploy",
		WithSigner("flow-evm-bridge"),
		WithArg("bytecode", erc721DeployerBytecode),
		WithArg("gasLimit", gasLimit),
		WithArg("value", deploymentValue),
	)
	checkNoErr(erc721DeployerDeployment.Err)
	erc721DeployerAddr := getContractAddressFromEVMEvent(erc721DeployerDeployment)

	log.Printf("ERC721 Deployer deployed to address: %s", factoryAddr)

	/* --- Cadence Configuration --- */

	log.Printf("Deploying Cadence contracts...")
	// Iterate over contracts in the contracts map
	for _, name := range contracts {
		contract, err := o.State.Config().Contracts.ByName(name)
		checkNoErr(err)
		contractPath := filepath.Join(projectRoot, contract.Location)
		contractCode, err := os.ReadFile(contractPath)
		checkNoErr(err)

		var args []cadence.Value
		if name == "FlowEVMBridgeUtils" {
			args = []cadence.Value{cadence.String(factoryAddr)}
		} else {
			args = []cadence.Value{}
		}

		err = o.AddContract(ctx, "flow-evm-bridge", contractCode, args, contractPath, false)
		checkNoErr(err)
	}
	log.Printf("Cadence contracts deployed...Pausing bridge for setup...")

	// Pause the bridge for setup
	var pauseResult = o.Tx("bridge/admin/pause/update_bridge_pause_status",
		WithSigner("flow-evm-bridge"),
		WithArg("pause", true),
	)
	checkNoErr(pauseResult.Err)
	log.Printf("Bridge paused, configuring token handlers...")

	// Add TokenHandler for specified Types
	// TODO

	log.Printf("Token handlers configured...continuing EVM setup...")

	/* --- Finish EVM Contract Setup --- */

	// Set the factory as registrar in the registry
	setRegistrarResult := o.Tx("bridge/admin/evm/set_registrar",
		WithSigner("flow-evm-bridge"),
		WithArg("registryEVMAddressHex", registryAddr),
	)
	checkNoErr(setRegistrarResult.Err)
	// Add the registry to the factory
	setRegistryResult := o.Tx("bridge/admin/evm/set_deployment_registry",
		WithSigner("flow-evm-bridge"),
		WithArg("registryEVMAddressHex", registryAddr),
	)
	checkNoErr(setRegistryResult.Err)

	// Set the factory as delegated deployer in the ERC20 deployer
	setDelegatedDeployerResult := o.Tx("bridge/admin/evm/set_delegated_deployer",
		WithSigner("flow-evm-bridge"),
		WithArg("deployerEVMAddressHex", erc20DeployerAddr),
	)
	checkNoErr(setDelegatedDeployerResult.Err)

	// Set the factory as delegated deployer in the ERC721 deployer
	setDelegatedDeployerResult = o.Tx("bridge/admin/evm/set_delegated_deployer",
		WithSigner("flow-evm-bridge"),
		WithArg("deployerEVMAddressHex", erc721DeployerAddr),
	)
	checkNoErr(setDelegatedDeployerResult.Err)

	// Add the ERC20 Deployer as a deployer in the factory
	addDeployerResult := o.Tx("bridge/admin/evm/add_deployer",
		WithSigner("flow-evm-bridge"),
		WithArg("deployerTag", "ERC20"),
		WithArg("deployerEVMAddressHex", erc20DeployerAddr),
	)
	checkNoErr(addDeployerResult.Err)

	// Add the ERC721 Deployer as a deployer in the factory
	addDeployerResult = o.Tx("bridge/admin/evm/add_deployer",
		WithSigner("flow-evm-bridge"),
		WithArg("deployerTag", "ERC721"),
		WithArg("deployerEVMAddressHex", erc721DeployerAddr),
	)

	log.Printf("EVM contract setup complete...integrating with EVM contract...")

	/* --- EVM Contract Integration --- */

	// Deploy FlowEVMBridgeAccessor, providing EVM contract host (network service account) as argument
	accessorContract, err := o.State.Config().Contracts.ByName("FlowEVMBridgeAccessor")
	checkNoErr(err)
	accessorPath := filepath.Join(projectRoot, accessorContract.Location)
	accessorCode, err := os.ReadFile(accessorPath)
	checkNoErr(err)
	evmConfigAddr, err := o.State.Config().Contracts.ByName("EVM")
	checkNoErr(err)
	evmAddr := evmConfigAddr.Aliases.ByNetwork(o.GetNetwork()).Address
	log.Printf("EVM contract address: %s", evmAddr)
	err = o.AddContract(ctx, "flow-evm-bridge", accessorCode, []cadence.Value{cadence.NewAddress(evmAddr)}, accessorPath, false)
	checkNoErr(err)

	// Integrate the EVM contract with the BridgeAccessor
	// bridgeContract, err := o.State.Config().Contracts.ByName("FlowEVMBridge")
	// checkNoErr(err)
	// bridgeAddr := bridgeContract.Aliases.ByNetwork(o.GetNetwork()).Address
	// integrateResult := o.Tx("bridge/admin/evm-integration/claim_accessor_capability_and_save_router",
	// 	WithSigner("service-account"),
	// 	WithArg("name", "FlowEVMBridgeAccessor"),
	// 	WithArg("provider", bridgeAddr),
	// )
	// checkNoErr(integrateResult.Err)

	log.Printf("EVM integration complete...setting fees...")

	/* --- Set Bridge Fees --- */

	onboardFeeResult := o.Tx("bridge/admin/fee/update_onboard_fee",
		WithSigner("flow-evm-bridge"),
		WithArg("newFee", 0.0),
	)
	checkNoErr(onboardFeeResult.Err)
	baseFeeResult := o.Tx("bridge/admin/fee/update_base_fee",
		WithSigner("flow-evm-bridge"),
		WithArg("newFee", 0.0),
	)
	checkNoErr(baseFeeResult.Err)

	log.Printf("Fees set...unpausing bridge...")

	// Unpause the bridge if everything was successful
	// pauseResult = o.Tx("bridge/admin/pause/update_bridge_pause_status",
	// WithSigner("flow-evm-bridge"),
	// WithArg("pause", false),
	// )
	// checkNoErr(pauseResult.Err)
	log.Printf("Done! Setup ALMOST complete....")
	log.Printf("NFT & Token templates MUST be added MANUALLY, EVM contract integrated, and then UNPAUSE bridge...")
}

func getSpecifiedNetwork() string {
	if len(os.Args) < 2 {
		log.Fatal("Please provide a network as an argument")
	}
	network := os.Args[1]

	if !slices.Contains(networks, network) {
		log.Fatal("Please provide a valid network as an argument")
	}
	return network
}

func getContractAddressFromEVMEvent(res *OverflowResult) string {
	evts := res.GetEventsWithName("TransactionExecuted")
	contractAddr := evts[0].Fields["contractAddress"]
	if contractAddr == nil {
		log.Fatal("Contract address not found in event")
	}
	return strings.ToLower(strings.Split(contractAddr.(string), "x")[1])
}

func getBytecodeFromArgsJSON(path string) string {
	argsData, err := os.ReadFile(path)
	checkNoErr(err)

	var args []map[string]string

	err = json.Unmarshal(argsData, &args)
	checkNoErr(err)

	return args[0]["value"]
}

func checkNoErr(err error) {
	if err != nil {
		log.Fatal(err)
	}
}
