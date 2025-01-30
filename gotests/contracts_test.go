package contracts_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	coreContracts "github.com/onflow/flow-core-contracts/lib/go/templates"
	"github.com/onflow/flow-evm-bridge/bridge"
)

const (
	fakeAddr = "0x0A"
)

func TestContract(t *testing.T) {
	coreEnv := coreContracts.Environment{
		FungibleTokenAddress: fakeAddr,
		ViewResolverAddress:  fakeAddr,
		BurnerAddress:        fakeAddr,
	}

	bridgeEnv := bridge.Environment{
		CrossVMNFTAddress: fakeAddr,
	}
	contract := bridge.GetCadenceCode("cadence/contracts/bridge/interfaces/CrossVMNFT.cdc", bridgeEnv, coreEnv)
	assert.NotNil(t, contract)
}
