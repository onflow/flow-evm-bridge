#!/bin/bash

# Create COA in emulator-account
flow transactions send ./cadence/transactions/evm/create_account.cdc 100.0

# Deploy supporting utils
flow accounts add-contract ./cadence/contracts/utils/ArrayUtils.cdc
flow accounts add-contract ./cadence/contracts/utils/StringUtils.cdc
flow accounts add-contract ./cadence/contracts/utils/ScopedFTProviders.cdc
flow accounts add-contract ./cadence/contracts/utils/Serialize.cdc
flow accounts add-contract ./cadence/contracts/utils/SerializeNFT.cdc

flow accounts update-contract ./cadence/contracts/standards/EVM.cdc

# Deploy initial bridge contracts
flow accounts add-contract ./cadence/contracts/bridge/BridgePermissions.cdc
flow accounts add-contract ./cadence/contracts/bridge/ICrossVM.cdc
flow accounts add-contract ./cadence/contracts/bridge/CrossVMNFT.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeConfig.cdc

# Deploy FlowEVMBridgeUtils also deploying FlowEVMBridgeFactory to EVM in init
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeUtils.cdc \
    --args-json "$(cat ./cadence/args/deploy-factory-args.json)"

flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeNFTEscrow.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeTemplates.cdc

# Add the templated contract code chunks for FlowEVMBridgedNFTTemplate.cdc contents
flow transactions send ./cadence/transactions/bridge/admin/upsert_contract_code_chunks.cdc \
    --args-json "$(cat ./cadence/args/bridged-nft-code-chunks-args.json)" --gas-limit 1600

flow accounts add-contract ./cadence/contracts/bridge/IEVMBridgeNFTMinter.cdc

# Deploy main bridge interface & contract
flow accounts add-contract ./cadence/contracts/bridge/IFlowEVMNFTBridge.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridge.cdc
