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

//go:embed cadence/transactions/bridge/admin/deploy_bridge_utils.cdc
//go:embed cadence/transactions/bridge/admin/deploy_bridge_accessor.cdc

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
//go:embed cadence/args/deploy-deployment-registry-args.json
//go:embed cadence/args/deploy-erc20-deployer-args.json
//go:embed cadence/args/deploy-erc721-deployer-args.json
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

func checkNoErr(err error) {
	if err != nil {
		log.Fatal(err)
	}
}
