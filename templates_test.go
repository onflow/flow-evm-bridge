package bridge_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	coreContracts "github.com/onflow/flow-core-contracts/lib/go/templates"
	bridge "github.com/onflow/flow-evm-bridge"
)

const (
	fakeAddr = "0x0A"
)

// Sets all the env addresses to the fakeAddr so they will all be used
// to replace import placeholders in the tests
func SetAllAddresses(bridgeEnv *bridge.Environment, coreEnv *coreContracts.Environment) {
	coreEnv.FungibleTokenAddress = fakeAddr
	coreEnv.EVMAddress = fakeAddr
	coreEnv.ViewResolverAddress = fakeAddr
	coreEnv.BurnerAddress = fakeAddr
	coreEnv.NonFungibleTokenAddress = fakeAddr
	coreEnv.MetadataViewsAddress = fakeAddr
	coreEnv.CrossVMMetadataViewsAddress = fakeAddr
	coreEnv.CryptoAddress = fakeAddr
	coreEnv.FlowFeesAddress = fakeAddr
	coreEnv.FlowTokenAddress = fakeAddr
	coreEnv.FungibleTokenMetadataViewsAddress = fakeAddr
	coreEnv.StorageFeesAddress = fakeAddr

	bridgeEnv.CrossVMNFTAddress = fakeAddr
	bridgeEnv.CrossVMTokenAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeHandlerInterfacesAddress = fakeAddr
	bridgeEnv.IBridgePermissionsAddress = fakeAddr
	bridgeEnv.ICrossVMAddress = fakeAddr
	bridgeEnv.ICrossVMAssetAddress = fakeAddr
	bridgeEnv.IEVMBridgeNFTMinterAddress = fakeAddr
	bridgeEnv.IEVMBridgeTokenMinterAddress = fakeAddr
	bridgeEnv.IFlowEVMNFTBridgeAddress = fakeAddr
	bridgeEnv.IFlowEVMTokenBridgeAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeAccessorAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeConfigAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeHandlersAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeNFTEscrowAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeResolverAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeTemplatesAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeTokenEscrowAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeUtilsAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeCustomAssociationTypesAddress = fakeAddr
	bridgeEnv.FlowEVMBridgeCustomAssociationsAddress = fakeAddr
	bridgeEnv.ArrayUtilsAddress = fakeAddr
	bridgeEnv.ScopedFTProvidersAddress = fakeAddr
	bridgeEnv.SerializeAddress = fakeAddr
	bridgeEnv.SerializeMetadataAddress = fakeAddr
	bridgeEnv.StringUtilsAddress = fakeAddr
}

// Tests that a specific contract path should succeed when retrieving it
// and verifies that all the import placeholders have been replaced
func GetCadenceContractShouldSucceed(t *testing.T, path string, bridgeEnv bridge.Environment, coreEnv coreContracts.Environment) {
	contract, err := bridge.GetCadenceContractCode(path, bridgeEnv, coreEnv)
	assert.Nil(t, err)
	assert.NotContains(t, string(contract), "import \"")
	assert.NotContains(t, string(contract), "import 0x")
}

// Tests that all the Cadence contract getters work properly
func TestCadenceContracts(t *testing.T) {
	coreEnv := coreContracts.Environment{
		FungibleTokenAddress: fakeAddr,
		ViewResolverAddress:  fakeAddr,
		BurnerAddress:        fakeAddr,
	}

	bridgeEnv := bridge.Environment{
		CrossVMNFTAddress: fakeAddr,
	}

	pathPrefix := "cadence/contracts/"

	// Should be missing NonFungibleToken, MetadataViews, EVM, and ICrossVMAsset
	contract, err := bridge.GetCadenceContractCode(pathPrefix+"bridge/interfaces/CrossVMNFT.cdc", bridgeEnv, coreEnv)
	assert.NotNil(t, contract)
	assert.NotNil(t, err)
	assert.Contains(t, err.Error(), "NonFungibleToken")
	assert.Contains(t, err.Error(), "MetadataViews")
	assert.Contains(t, err.Error(), "EVM")
	assert.Contains(t, err.Error(), "ICrossVMAsset")

	SetAllAddresses(&bridgeEnv, &coreEnv)

	contract, err = bridge.GetCadenceContractCode(pathPrefix+"utils/StringUtils.cdc", bridgeEnv, coreEnv)
	assert.NotNil(t, contract)
	assert.Contains(t, string(contract), "import ")
	assert.Contains(t, string(contract), " from ")

	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/interfaces/CrossVMToken.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/interfaces/FlowEVMBridgeHandlerInterfaces.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/interfaces/IBridgePermissions.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/interfaces/ICrossVM.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/interfaces/ICrossVMAsset.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/interfaces/IEVMBridgeNFTMinter.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/interfaces/IEVMBridgeTokenMinter.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/interfaces/IFlowEVMNFTBridge.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/interfaces/IFlowEVMTokenBridge.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridge.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeConfig.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeHandlers.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeNFTEscrow.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeResolver.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeTemplates.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeTokenEscrow.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeUtils.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeCustomAssociationTypes.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeCustomAssociations.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"utils/ArrayUtils.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"utils/ScopedFTProviders.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"utils/Serialize.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"utils/SerializeMetadata.cdc", bridgeEnv, coreEnv)
	GetCadenceContractShouldSucceed(t, pathPrefix+"utils/StringUtils.cdc", bridgeEnv, coreEnv)

	GetCadenceContractShouldSucceed(t, pathPrefix+"bridge/FlowEVMBridgeAccessor.cdc", bridgeEnv, coreEnv)
	contract, err = bridge.GetCadenceContractCode(pathPrefix+"bridge/FlowEVMBridgeAccessor.cdc", bridgeEnv, coreEnv)
	assert.Contains(t, string(contract), "name: \"FlowEVMBridgeAccessor\"")
}

// Tests that a specific solidity contract name should succeed when retrieving it
// and verifies that it contains bytecode
func GetSolidityContractShouldSucceed(t *testing.T, name string) {
	byteCode, err := bridge.GetSolidityContractCode(name)
	assert.Nil(t, err)
	assert.NotContains(t, byteCode, "access(all)")
	assert.NotContains(t, byteCode, "//")
	assert.NotContains(t, byteCode, "import")
}

// Tests that all the Solidity contract getters work properly
func TestSolidityContracts(t *testing.T) {

	// Should be invalid contract name
	_, err := bridge.GetSolidityContractCode("CryptoPunks")
	assert.NotNil(t, err)
	assert.Contains(t, err.Error(), "Invalid Solidity Contract Name CryptoPunks")

	GetSolidityContractShouldSucceed(t, "FlowBridgeFactory")
	GetSolidityContractShouldSucceed(t, "FlowEVMBridgedERC20Deployer")
	GetSolidityContractShouldSucceed(t, "FlowEVMBridgedERC721Deployer")
	GetSolidityContractShouldSucceed(t, "FlowBridgeDeploymentRegistry")
	GetSolidityContractShouldSucceed(t, "FlowEVMBridgedERC721")
	GetSolidityContractShouldSucceed(t, "FlowEVMBridgedERC20")
	GetSolidityContractShouldSucceed(t, "WFLOW")
}

// Tests that a specific script path should succeed when retrieving it
// and verifies that all the import placeholders have been replaced
func GetScriptShouldSucceed(t *testing.T, path string, bridgeEnv bridge.Environment, coreEnv coreContracts.Environment) {
	script, err := bridge.GetCadenceScriptCode(path, bridgeEnv, coreEnv)
	assert.Nil(t, err)
	assert.NotContains(t, string(script), "import \"")
	assert.NotContains(t, string(script), "import 0x")
}

func TestScripts(t *testing.T) {
	coreEnv := coreContracts.Environment{
		FungibleTokenAddress: fakeAddr,
		ViewResolverAddress:  fakeAddr,
		BurnerAddress:        fakeAddr,
	}

	bridgeEnv := bridge.Environment{
		CrossVMNFTAddress: fakeAddr,
	}

	pathPrefix := "cadence/scripts/"

	// Should be missing EVM and FlowEVMBridge
	script, err := bridge.GetCadenceScriptCode(pathPrefix+"bridge/batch_evm_address_requires_onboarding.cdc", bridgeEnv, coreEnv)
	assert.NotNil(t, script)
	assert.NotNil(t, err)
	assert.Contains(t, err.Error(), "EVM")
	assert.Contains(t, err.Error(), "FlowEVMBridge")

	SetAllAddresses(&bridgeEnv, &coreEnv)

	GetScriptShouldSucceed(t, pathPrefix+"bridge/batch_get_associated_evm_address.cdc", bridgeEnv, coreEnv)
}

// Tests that a specific transaction path should succeed when retrieving it
// and verifies that all the import placeholders have been replaced
func GetTransactionShouldSucceed(t *testing.T, path string, bridgeEnv bridge.Environment, coreEnv coreContracts.Environment) {
	tx, err := bridge.GetCadenceTransactionCode(path, bridgeEnv, coreEnv)
	assert.Nil(t, err)
	assert.NotContains(t, string(tx), "import \"")
	assert.NotContains(t, string(tx), "import 0x")
}

func TestTransactions(t *testing.T) {
	coreEnv := coreContracts.Environment{
		FungibleTokenAddress: fakeAddr,
		ViewResolverAddress:  fakeAddr,
		BurnerAddress:        fakeAddr,
	}

	bridgeEnv := bridge.Environment{
		CrossVMNFTAddress: fakeAddr,
	}

	pathPrefix := "cadence/transactions/"

	// Should be missing EVM and FlowEVMBridgeConfig
	tx, err := bridge.GetCadenceTransactionCode(pathPrefix+"bridge/admin/blocklist/block_cadence_type.cdc", bridgeEnv, coreEnv)
	assert.NotNil(t, tx)
	assert.NotNil(t, err)
	assert.Contains(t, err.Error(), "EVM")
	assert.Contains(t, err.Error(), "FlowEVMBridgeConfig")

	SetAllAddresses(&bridgeEnv, &coreEnv)

	GetTransactionShouldSucceed(t, pathPrefix+"bridge/admin/blocklist/block_evm_address.cdc", bridgeEnv, coreEnv)
	GetTransactionShouldSucceed(t, pathPrefix+"evm/create_account.cdc", bridgeEnv, coreEnv)
}
