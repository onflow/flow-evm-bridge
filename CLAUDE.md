# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flow EVM Bridge enables atomic, bidirectional bridging of fungible tokens (FT) and non-fungible tokens (NFT) between Flow's Cadence VM and Flow's EVM. It is deployed on both Mainnet and Testnet.

**Languages:** Cadence (primary smart contracts), Solidity (EVM-side contracts), Go (template embedding and import resolution for deployment tooling)

## Build & Test Commands

```bash
make test          # Run all tests (Cadence + Go)
make cdc-test      # Cadence tests with coverage via Flow CLI
make go-test       # Go unit tests (templates.go import resolution)
make ci            # CI pipeline: check-tidy + test
make check-tidy    # Validate go.mod is tidy

# Run a single Cadence test file
flow test cadence/tests/flow_evm_bridge_tests.cdc

# Solidity (Foundry)
forge build --sizes
forge test -vvv
```

**Prerequisites:** Flow CLI, Go 1.23+, Foundry (for Solidity work)

Before running Cadence tests, install Flow dependencies:
```bash
flow deps install --skip-alias --skip-deployments
```

## Architecture

### Cadence Side (`cadence/`)

**Core bridge contracts** (`cadence/contracts/bridge/`):
- `FlowEVMBridge.cdc` — Main orchestrator implementing `IFlowEVMNFTBridge` and `IFlowEVMTokenBridge`. Entry points: `bridgeNFTToEVM`, `bridgeNFTFromEVM`, `bridgeTokensToEVM`, `bridgeTokensFromEVM`, and `onboardByType`/`onboardByEVMAddress` for asset registration.
- `FlowEVMBridgeConfig.cdc` — Pausability, fee configuration, blocklists
- `FlowEVMBridgeHandlers.cdc` — Custom handler registry for tokens needing special bridging logic (e.g., WFLOW wrapping/unwrapping)
- `FlowEVMBridgeNFTEscrow.cdc` / `FlowEVMBridgeTokenEscrow.cdc` — Secure escrow for locked Cadence assets during bridging
- `FlowEVMBridgeUtils.cdc` — Large utility library (~69KB) for type checking, metadata handling, fee calculations, EVM calls
- `FlowEVMBridgeResolver.cdc` — Type/address association resolution
- `FlowEVMBridgeCustomAssociations.cdc` — Non-standard Cadence↔EVM mappings for custom cross-VM implementations
- `FlowEVMBridgeTemplates.cdc` — Template contract code storage for deploying bridged asset contracts

**Interfaces** (`cadence/contracts/bridge/interfaces/`):
- `ICrossVM.cdc` — Exposes EVM address for cross-VM resources
- `CrossVMNFT.cdc` / `CrossVMToken.cdc` — Extensions for EVM ID tracking on NFTs/FTs
- `IFlowEVMNFTBridge.cdc` / `IFlowEVMTokenBridge.cdc` — Public bridge APIs
- `FlowEVMBridgeHandlerInterfaces.cdc` — Handler extensibility

**Utility contracts** (`cadence/contracts/utils/`): `ArrayUtils`, `StringUtils`, `Serialize`, `SerializeMetadata`, `ScopedFTProviders`

### Solidity Side (`solidity/`)

- `FlowBridgeFactory.sol` — Owner-controlled factory that manages deployer contracts
- `FlowEVMBridgedERC20.sol` / `FlowEVMBridgedERC721.sol` — Template contracts deployed for each bridged asset, with bridge-controlled minting/burning
- `FlowBridgeDeploymentRegistry.sol` — Maps Cadence type identifiers to deployed EVM contract addresses
- Dependencies managed via git submodules (OpenZeppelin, forge-std) in `solidity/lib/`

### Go Package (`templates.go`)

Embeds all Cadence contract, script, and transaction source files via `//go:embed`. Provides functions to retrieve contract code with import addresses resolved (replacing placeholder import strings like `"FlowEVMBridge"` with actual network addresses). Used by deployment tooling and downstream consumers.

### Key Flow

1. **Onboarding**: Assets must be registered with the bridge before first use. This deploys a corresponding EVM contract (ERC20/ERC721) via the factory or registers a custom association.
2. **Bridging to EVM**: Cadence asset is locked in escrow → EVM token minted to recipient's EVM address
3. **Bridging from EVM**: EVM token burned → Cadence asset released from escrow to recipient
4. All bridging initiates from Cadence via CadenceOwnedAccount (COA) resources

## Configuration

- `flow.json` — Flow CLI config with contract definitions, network aliases (emulator/testnet/mainnet), deployment accounts, and dependency declarations
- `foundry.toml` — Foundry config pointing to `solidity/` subdirectories
- `imports/` — Cached Flow dependency contracts fetched by `flow deps install`

## Testing

Cadence tests are in `cadence/tests/*_tests.cdc`. The main test helper file (`cadence/tests/test_helpers.cdc`, ~342KB) contains extensive setup utilities shared across all test files. Test contracts used in testing are in `cadence/tests/contracts/`.

Go tests (`templates_test.go`) validate that all embedded contracts load correctly and that import placeholder substitution works for all contract/script/transaction paths.

Solidity tests are in `solidity/test/` and run via Foundry (`forge test`).
