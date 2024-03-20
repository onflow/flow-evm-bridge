#!/bin/bash

flow transactions send ./cadence/transactions/evm/create_account.cdc 100.0

flow accounts add-contract ./cadence/contracts/utils/ArrayUtils.cdc
flow accounts add-contract ./cadence/contracts/utils/StringUtils.cdc
flow accounts add-contract ./cadence/contracts/utils/ScopedFTProviders.cdc

flow accounts update-contract ./cadence/contracts/standards/EVM.cdc

# Create COA in emulator-account

# Deploy initial bridge contracts
flow accounts add-contract ./cadence/contracts/bridge/BridgePermissions.cdc
flow accounts add-contract ./cadence/contracts/bridge/ICrossVM.cdc
flow accounts add-contract ./cadence/contracts/bridge/CrossVMNFT.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeConfig.cdc


flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeUtils.cdc \
    --args-json "$(cat ./cadence/args/deploy-factory-args.json)"

flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeNFTEscrow.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeTemplates.cdc
# Add the templated contract code chunks for FlowEVMBridgedNFTTemplate.cdc contents
flow transactions send ./cadence/transactions/bridge/admin/upsert_contract_code_chunks.cdc \
    --args-json "$(cat ./cadence/args/bridged-nft-code-chunks-args.json)" --gas-limit 1600

flow accounts add-contract ./cadence/contracts/bridge/IEVMBridgeNFTMinter.cdc

# Deploy Serialization Utils
flow accounts add-contract ./cadence/contracts/utils/Serialize.cdc
flow accounts add-contract ./cadence/contracts/utils/SerializeNFT.cdc

# Deploy main bridge interface & contract
flow accounts add-contract ./cadence/contracts/bridge/IFlowEVMNFTBridge.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridge.cdc