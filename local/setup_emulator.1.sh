#!/bin/bash

# Create COA in emulator-account
flow-c1 transactions send ./cadence/transactions/evm/create_account.cdc 100.0

# Deploy supporting utils
flow-c1 accounts add-contract ./cadence/contracts/utils/ArrayUtils.cdc
flow-c1 accounts add-contract ./cadence/contracts/utils/StringUtils.cdc
flow-c1 accounts add-contract ./cadence/contracts/utils/ScopedFTProviders.cdc
flow-c1 accounts add-contract ./cadence/contracts/utils/Serialize.cdc
flow-c1 accounts add-contract ./cadence/contracts/utils/SerializeNFT.cdc

flow-c1 accounts update-contract ./cadence/contracts/standards/EVM.cdc

# Deploy initial bridge contracts
flow-c1 accounts add-contract ./cadence/contracts/bridge/BridgePermissions.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/ICrossVM.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/CrossVMNFT.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeConfig.cdc

# Deploy FlowEVMBridgeUtils also deploying FlowEVMBridgeFactory to EVM in init
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeUtils.cdc \
    --args-json "$(cat ./cadence/args/deploy-factory-args.json)"

flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeNFTEscrow.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeTemplates.cdc

# Add the templated contract code chunks for FlowEVMBridgedNFTTemplate.cdc contents
flow-c1 transactions send ./cadence/transactions/bridge/admin/upsert_contract_code_chunks.cdc \
    --args-json "$(cat ./cadence/args/bridged-nft-code-chunks-args.json)" --gas-limit 1600

flow-c1 accounts add-contract ./cadence/contracts/bridge/IEVMBridgeNFTMinter.cdc

# Deploy main bridge interface & contract
flow-c1 accounts add-contract ./cadence/contracts/bridge/IFlowEVMNFTBridge.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridge.cdc
