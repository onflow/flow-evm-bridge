package bridge

import (
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"strings"

	coreContracts "github.com/onflow/flow-core-contracts/lib/go/templates"
)

//go:embed cadence/contracts/bridge/interfaces/CrossVMNFT.cdc
//go:embed cadence/contracts/bridge/interfaces/CrossVMToken.cdc
//go:embed cadence/contracts/bridge/interfaces/FlowEVMBridgeHandlerInterfaces.cdc
//go:embed cadence/contracts/bridge/interfaces/IBridgePermissions.cdc
//go:embed cadence/contracts/bridge/interfaces/ICrossVM.cdc
//go:embed cadence/contracts/bridge/interfaces/ICrossVMAsset.cdc
//go:embed cadence/contracts/bridge/interfaces/IEVMBridgeNFTMinter.cdc
//go:embed cadence/contracts/bridge/interfaces/IEVMBridgeTokenMinter.cdc
//go:embed cadence/contracts/bridge/interfaces/IFlowEVMNFTBridge.cdc
//go:embed cadence/contracts/bridge/interfaces/IFlowEVMTokenBridge.cdc
//go:embed cadence/contracts/bridge/FlowEVMBridge.cdc
//go:embed cadence/contracts/bridge/FlowEVMBridgeAccessor.cdc
//go:embed cadence/contracts/bridge/FlowEVMBridgeConfig.cdc
//go:embed cadence/contracts/bridge/FlowEVMBridgeHandlers.cdc
//go:embed cadence/contracts/bridge/FlowEVMBridgeNFTEscrow.cdc
//go:embed cadence/contracts/bridge/FlowEVMBridgeResolver.cdc
//go:embed cadence/contracts/bridge/FlowEVMBridgeTemplates.cdc
//go:embed cadence/contracts/bridge/FlowEVMBridgeTokenEscrow.cdc
//go:embed cadence/contracts/bridge/FlowEVMBridgeUtils.cdc
//go:embed cadence/contracts/utils/ArrayUtils.cdc
//go:embed cadence/contracts/utils/ScopedFTProviders.cdc
//go:embed cadence/contracts/utils/Serialize.cdc
//go:embed cadence/contracts/utils/SerializeMetadata.cdc
//go:embed cadence/contracts/utils/StringUtils.cdc

//go:embed cadence/scripts/bridge/batch_evm_address_requires_onboarding.cdc
//go:embed cadence/scripts/bridge/batch_get_associated_evm_address.cdc
//go:embed cadence/scripts/bridge/batch_get_associated_type.cdc
//go:embed cadence/scripts/bridge/batch_type_requires_onboarding.cdc
//go:embed cadence/scripts/bridge/calculate_bridge_fee.cdc
//go:embed cadence/scripts/bridge/evm_address_requires_onboarding.cdc
//go:embed cadence/scripts/bridge/get_associated_evm_address.cdc
//go:embed cadence/scripts/bridge/get_associated_type.cdc
//go:embed cadence/scripts/bridge/get_bridge_coa_address.cdc
//go:embed cadence/scripts/bridge/get_gas_limit.cdc
//go:embed cadence/scripts/bridge/is_cadence_type_blocked.cdc
//go:embed cadence/scripts/bridge/is_evm_address_blocked.cdc
//go:embed cadence/scripts/bridge/is_paused.cdc
//go:embed cadence/scripts/bridge/is_type_paused.cdc
//go:embed cadence/scripts/bridge/type_requires_onboarding.cdc
//go:embed cadence/scripts/bridge/type_requires_onboarding_by_identifier.cdc

//go:embed cadence/scripts/config/get_base_fee.cdc
//go:embed cadence/scripts/config/get_onboard_fee.cdc

//go:embed cadence/scripts/escrow/get_locked_token_balance.cdc
//go:embed cadence/scripts/escrow/get_nft_views.cdc
//go:embed cadence/scripts/escrow/get_vault_views.cdc
//go:embed cadence/scripts/escrow/is_nft_locked.cdc
//go:embed cadence/scripts/escrow/resolve_locked_nft_metadata.cdc
//go:embed cadence/scripts/escrow/resolve_locked_vault_metadata.cdc

//go:embed cadence/scripts/evm/call.cdc
//go:embed cadence/scripts/evm/get_balance.cdc
//go:embed cadence/scripts/evm/get_evm_address_string.cdc
//go:embed cadence/scripts/evm/get_evm_address_string_from_bytes.cdc

//go:embed cadence/scripts/nft/get_evm_id_from_evm_nft.cdc
//go:embed cadence/scripts/nft/get_ids.cdc
//go:embed cadence/scripts/nft/has_collection_configured.cdc

//go:embed cadence/scripts/serialize/serialize_nft.cdc

//go:embed cadence/scripts/tokens/get_all_vault_info_from_storage.cdc
//go:embed cadence/scripts/tokens/get_balance.cdc
//go:embed cadence/scripts/tokens/has_vault_configured.cdc
//go:embed cadence/scripts/tokens/total_supply.cdc

//go:embed cadence/scripts/utils/balance_of.cdc
//go:embed cadence/scripts/utils/derive_bridged_nft_contract_name.cdc
//go:embed cadence/scripts/utils/derive_bridged_token_contract_name.cdc
//go:embed cadence/scripts/utils/get_deployer_address.cdc
//go:embed cadence/scripts/utils/get_evm_address_from_hex.cdc
//go:embed cadence/scripts/utils/get_factory_address.cdc
//go:embed cadence/scripts/utils/get_registry_address.cdc
//go:embed cadence/scripts/utils/get_token_decimals.cdc
//go:embed cadence/scripts/utils/is_owner.cdc
//go:embed cadence/scripts/utils/is_owner_or_approved.cdc
//go:embed cadence/scripts/utils/token_uri.cdc
//go:embed cadence/scripts/utils/total_supply.cdc

//go:embed cadence/transactions/bridge/admin/blocklist/block_cadence_type.cdc
//go:embed cadence/transactions/bridge/admin/blocklist/block_evm_address.cdc
//go:embed cadence/transactions/bridge/admin/blocklist/unblock_cadence_type.cdc
//go:embed cadence/transactions/bridge/admin/blocklist/unblock_evm_address.cdc
//go:embed cadence/transactions/bridge/admin/evm-integration/claim_accessor_capability_and_save_router.cdc
//go:embed cadence/transactions/bridge/admin/evm/add_deployer.cdc
//go:embed cadence/transactions/bridge/admin/evm/set_delegated_deployer.cdc
//go:embed cadence/transactions/bridge/admin/evm/set_deployment_registry.cdc
//go:embed cadence/transactions/bridge/admin/evm/set_registrar.cdc
//go:embed cadence/transactions/bridge/admin/evm/upsert_deployer.cdc
//go:embed cadence/transactions/bridge/admin/fee/update_base_fee.cdc
//go:embed cadence/transactions/bridge/admin/fee/update_onboard_fee.cdc
//go:embed cadence/transactions/bridge/admin/gas/set_gas_limit.cdc
//go:embed cadence/transactions/bridge/admin/metadata/set_bridged_ft_display_view.cdc
//go:embed cadence/transactions/bridge/admin/metadata/set_bridged_nft_collection_display_view.cdc
//go:embed cadence/transactions/bridge/admin/metadata/set_bridged_nft_display_view.cdc
//go:embed cadence/transactions/bridge/admin/pause/update_bridge_pause_status.cdc
//go:embed cadence/transactions/bridge/admin/pause/update_type_pause_status.cdc
//go:embed cadence/transactions/bridge/admin/templates/upsert_contract_code_chunks.cdc
//go:embed cadence/transactions/bridge/admin/token-handler/create_cadence_native_token_handler.cdc
//go:embed cadence/transactions/bridge/admin/token-handler/create_wflow_token_handler.cdc
//go:embed cadence/transactions/bridge/admin/token-handler/disable_token_handler.cdc
//go:embed cadence/transactions/bridge/admin/token-handler/enable_token_handler.cdc
//go:embed cadence/transactions/bridge/admin/token-handler/send_minter_to_bridge.cdc
//go:embed cadence/transactions/bridge/admin/token-handler/set_handler_target_evm_address.cdc
//go:embed cadence/transactions/bridge/admin/token-handler/set_token_handler_minter.cdc

//go:embed cadence/transactions/bridge/nft/batch_bridge_nft_from_evm.cdc
//go:embed cadence/transactions/bridge/nft/batch_bridge_nft_to_any_cadence_address.cdc
//go:embed cadence/transactions/bridge/nft/batch_bridge_nft_to_any_evm_address.cdc
//go:embed cadence/transactions/bridge/nft/batch_bridge_nft_to_evm.cdc
//go:embed cadence/transactions/bridge/nft/bridge_nft_from_evm.cdc
//go:embed cadence/transactions/bridge/nft/bridge_nft_to_any_cadence_address.cdc
//go:embed cadence/transactions/bridge/nft/bridge_nft_to_any_evm_address.cdc
//go:embed cadence/transactions/bridge/nft/bridge_nft_to_evm.cdc

//go:embed cadence/transactions/bridge/onboarding/batch_onboard_by_evm_address.cdc
//go:embed cadence/transactions/bridge/onboarding/batch_onboard_by_type.cdc
//go:embed cadence/transactions/bridge/onboarding/onboard_by_evm_address.cdc
//go:embed cadence/transactions/bridge/onboarding/onboard_by_type.cdc
//go:embed cadence/transactions/bridge/onboarding/onboard_by_type_identifier.cdc

//go:embed cadence/transactions/bridge/tokens/bridge_tokens_from_evm.cdc
//go:embed cadence/transactions/bridge/tokens/bridge_tokens_to_any_cadence_address.cdc
//go:embed cadence/transactions/bridge/tokens/bridge_tokens_to_any_evm_address.cdc
//go:embed cadence/transactions/bridge/tokens/bridge_tokens_to_evm.cdc

//go:embed cadence/transactions/evm/call.cdc
//go:embed cadence/transactions/evm/create_account.cdc
//go:embed cadence/transactions/evm/create_new_account_with_coa.cdc
//go:embed cadence/transactions/evm/deploy.cdc
//go:embed cadence/transactions/evm/deposit.cdc
//go:embed cadence/transactions/evm/destroy_coa.cdc
//go:embed cadence/transactions/evm/transfer_flow_from_coa_to_evm_address.cdc
//go:embed cadence/transactions/evm/transfer_flow_to_evm_address.cdc
//go:embed cadence/transactions/evm/withdraw.cdc

//go:embed cadence/tests/test_helpers.cdc

//go:embed cadence/args/bridged-nft-code-chunks-args-emulator.json
//go:embed cadence/args/bridged-token-code-chunks-args-emulator.json
//go:embed cadence/args/deploy-factory-args.json
var content embed.FS

var (
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

func ReplaceAddress(code, placeholder, replacement string) string {
	if len(replacement) > 0 {
		placeholderWithoutQuotes := placeholder[1 : len(placeholder)-1]
		code = strings.ReplaceAll(
			code,
			placeholder,
			placeholderWithoutQuotes+"from "+withHexPrefix(replacement),
		)
	}
	return code
}

func ReplaceAddresses(code string, bridgeEnv Environment, coreEnv coreContracts.Environment) string {

	code = ReplaceAddress(
		code,
		placeholderCrossVMNFTAddress,
		bridgeEnv.CrossVMNFTAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderCrossVMTokenAddress,
		bridgeEnv.CrossVMTokenAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeHandlerInterfacesAddress,
		bridgeEnv.FlowEVMBridgeHandlerInterfacesAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderIBridgePermissionsAddress,
		bridgeEnv.IBridgePermissionsAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderICrossVMAddress,
		bridgeEnv.ICrossVMAddress,
	)
	code = ReplaceAddress(
		code,
		placeholderICrossVMAssetAddress,
		bridgeEnv.ICrossVMAssetAddress,
	)
	code = ReplaceAddress(
		code,
		placeholderIEVMBridgeNFTMinterAddress,
		bridgeEnv.IEVMBridgeNFTMinterAddress,
	)
	code = ReplaceAddress(
		code,
		placeholderIEVMBridgeTokenMinterAddress,
		bridgeEnv.IEVMBridgeTokenMinterAddress,
	)
	code = ReplaceAddress(
		code,
		placeholderIFlowEVMNFTBridgeAddress,
		bridgeEnv.IFlowEVMNFTBridgeAddress,
	)
	code = ReplaceAddress(
		code,
		placeholderIFlowEVMTokenBridgeAddress,
		bridgeEnv.IFlowEVMTokenBridgeAddress,
	)
	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeAddress,
		bridgeEnv.FlowEVMBridgeAddress,
	)
	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeAccessorAddress,
		bridgeEnv.FlowEVMBridgeAccessorAddress,
	)
	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeConfigAddress,
		bridgeEnv.FlowEVMBridgeConfigAddress,
	)
	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeHandlersAddress,
		bridgeEnv.FlowEVMBridgeHandlersAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeNFTEscrowAddress,
		bridgeEnv.FlowEVMBridgeNFTEscrowAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeResolverAddress,
		bridgeEnv.FlowEVMBridgeResolverAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeTemplatesAddress,
		bridgeEnv.FlowEVMBridgeTemplatesAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeTokenEscrowAddress,
		bridgeEnv.FlowEVMBridgeTokenEscrowAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderFlowEVMBridgeUtilsAddress,
		bridgeEnv.FlowEVMBridgeUtilsAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderArrayUtilsAddress,
		bridgeEnv.ArrayUtilsAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderScopedFTProvidersAddress,
		bridgeEnv.ScopedFTProvidersAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderSerializeAddress,
		bridgeEnv.SerializeAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderSerializeMetadataAddress,
		bridgeEnv.SerializeMetadataAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderStringUtilsAddress,
		bridgeEnv.StringUtilsAddress,
	)

	code = coreContracts.ReplaceAddresses(code, coreEnv)

	return code
}

// Gets the byte representation of a bridge Cadence contract
// Caller must provide the full path to the contract
func GetCadenceContractCode(contractPath string, bridgeEnv Environment, coreEnv coreContracts.Environment) ([]byte, error) {

	fileContent, err := content.ReadFile(contractPath)

	if err != nil {
		log.Fatal(err)
	}

	// Convert []byte to string
	code := string(fileContent)

	code = ReplaceAddresses(code, bridgeEnv, coreEnv)

	missingImportsString := ""

	if strings.Contains(code, "import \"") {
		quoteSeparated := strings.Split(code, "\"")
		contractNames := make([]string, len(quoteSeparated))
		i := 0
		for _, name := range quoteSeparated {
			if strings.Contains(name, "access(all) contract ") {
				break
			}
			if strings.Contains(name, "import") {
				continue
			} else {
				contractNames[i] = name
				i = i + 1
			}
		}
		missingImportsString = "Cannot return code for " + contractPath + ". Missing import addresses for "
		for _, name := range contractNames {
			if len(name) > 0 {
				missingImportsString = missingImportsString + name + ", "
			}
		}
		missingImportsString = missingImportsString[:len(missingImportsString)-2]
		missingImportsString = missingImportsString + "."
		return []byte(code), errors.New(missingImportsString)
	}

	return []byte(code), nil
}

type Element struct {
	Type  string      `json:"type"`
	Value interface{} `json:"value"`
}

// Gets JSON Arguments with the chunked versions of
// the Cadence NFT or Fungible Token template contract
func GetCadenceTokenChunkedJSONArguments(nft bool) []string {
	filePath := ""

	if nft {
		filePath = "cadence/args/bridged-nft-code-chunks-args-emulator.json"
	} else {
		filePath = "cadence/args/bridged-token-code-chunks-args-emulator.json"
	}

	file, err := content.Open(filePath)

	if err != nil {
		log.Fatalf("Failed opening file: %s", err)
	}
	defer file.Close()

	byteValue, _ := ioutil.ReadAll(file)

	var elements []Element
	json.Unmarshal(byteValue, &elements)

	secondElement := elements[1]

	// Check if the second element is of type "Array"
	if secondElement.Type != "Array" {
		log.Fatalf("Second element is not of type Array")
	}

	// Assert that the value is a slice of interfaces
	values, ok := secondElement.Value.([]interface{})
	if !ok {
		log.Fatalf("Failed to assert value to []interface{}")
	}

	var strArr []string
	for _, v := range values {
		// Assert that the value is a map
		valueMap, ok := v.(map[string]interface{})
		if !ok {
			log.Fatalf("Failed to assert value to map[string]interface{}")
		}

		// Get the "value" from the map and assert it to string
		str, ok := valueMap["value"].(string)
		if !ok {
			log.Fatalf("Failed to assert value to string")
		}

		strArr = append(strArr, str)
	}

	return strArr
}

// Reads the JSON file at the specified path and returns the compiled solidity bytecode where the
// bytecode is the first element in the JSON array as a Cadence JSON string
func GetBytecodeFromArgsJSON(path string) string {
	file, err := content.Open(path)
	if err != nil {
		log.Fatalf("Failed opening file: %s", err)
	}
	defer file.Close()

	byteValue, _ := ioutil.ReadAll(file)

	var args []map[string]string

	err = json.Unmarshal(byteValue, &args)
	checkNoErr(err)

	return args[0]["value"]
}

func GetCadenceTransactionCode(transactionPath string, bridgeEnv Environment, coreEnv coreContracts.Environment) ([]byte, error) {

	fileContent, err := content.ReadFile(transactionPath)

	if err != nil {
		log.Fatal(err)
	}

	// Convert []byte to string
	code := string(fileContent)

	code = ReplaceAddresses(code, bridgeEnv, coreEnv)

	missingImportsString := ""

	if strings.Contains(code, "import \"") {
		quoteSeparated := strings.Split(code, "\"")
		contractNames := make([]string, len(quoteSeparated))
		i := 0
		for _, name := range quoteSeparated {
			if strings.Contains(name, "transaction(") {
				break
			}
			if strings.Contains(name, "import") {
				continue
			} else {
				contractNames[i] = name
				i = i + 1
			}
		}
		missingImportsString = "Cannot return code for " + transactionPath + ". Missing import addresses for "
		for _, name := range contractNames {
			if len(name) > 0 {
				missingImportsString = missingImportsString + name + ", "
			}
		}
		missingImportsString = missingImportsString[:len(missingImportsString)-2]
		missingImportsString = missingImportsString + "."
		return []byte(code), errors.New(missingImportsString)
	}

	return []byte(code), nil
}

func GetCadenceScriptCode(scriptPath string, bridgeEnv Environment, coreEnv coreContracts.Environment) ([]byte, error) {

	fileContent, err := content.ReadFile(scriptPath)

	if err != nil {
		log.Fatal(err)
	}

	// Convert []byte to string
	code := string(fileContent)

	code = ReplaceAddresses(code, bridgeEnv, coreEnv)

	missingImportsString := ""

	if strings.Contains(code, "import \"") {
		quoteSeparated := strings.Split(code, "\"")
		contractNames := make([]string, len(quoteSeparated))
		i := 0
		for _, name := range quoteSeparated {
			if strings.Contains(name, "access(all) fun main(") {
				break
			}
			if strings.Contains(name, "import") {
				continue
			} else {
				contractNames[i] = name
				i = i + 1
			}
		}
		missingImportsString = "Cannot return code for " + scriptPath + ". Missing import addresses for "
		for _, name := range contractNames {
			if len(name) > 0 {
				missingImportsString = missingImportsString + name + ", "
			}
		}
		missingImportsString = missingImportsString[:len(missingImportsString)-2]
		missingImportsString = missingImportsString + "."
		return []byte(code), errors.New(missingImportsString)
	}

	return []byte(code), nil
}

func GetSolidityContractCode(contractName string) (string, error) {

	fileContent, _ := content.ReadFile("cadence/tests/test_helpers.cdc")

	// Convert []byte to string
	fullFile := string(fileContent)

	quoteSeparated := strings.Split(fullFile, "\"")
	switch contractName {
	case "FlowBridgeFactory":
		return quoteSeparated[13], nil
	case "FlowEVMBridgedERC20Deployer":
		return quoteSeparated[15], nil
	case "FlowEVMBridgedERC721Deployer":
		return quoteSeparated[17], nil
	case "FlowBridgeDeploymentRegistry":
		return quoteSeparated[19], nil
	case "FlowEVMBridgedERC721":
		return quoteSeparated[21], nil
	case "FlowEVMBridgedERC20":
		return quoteSeparated[23], nil
	case "WFLOW":
		return quoteSeparated[25], nil
	default:
		return "", errors.New("Invalid Solidity Contract Name " + contractName)
	}
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
// 	// Get the Cadence args json for the registry deployment args
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

func buildUSDCFlowVaultIdentifier(addrString string) string {
	return "A." + strings.Split(addrString, "x")[1] + ".USDCFlow.Vault"
}

func buildUSDCFlowMinterIdentifier(addrString string) string {
	return "A." + strings.Split(addrString, "x")[1] + ".USDCFlow.Minter"
}

func checkNoErr(err error) {
	if err != nil {
		log.Fatal(err)
	}
}
