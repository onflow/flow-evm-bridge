#!/bin/bash

flow-c1 transactions send ./cadence/transactions/evm/create_account.cdc 100.0

flow-c1 accounts add-contract ./cadence/contracts/utils/ArrayUtils.cdc
flow-c1 accounts add-contract ./cadence/contracts/utils/StringUtils.cdc
flow-c1 accounts add-contract ./cadence/contracts/utils/ScopedFTProviders.cdc

flow-c1 accounts update-contract ./cadence/contracts/standards/EVM.cdc

# Create COA in emulator-account

# Deploy the Factory contract - NOTE THE `deployedContractAddress` IN THE EMITTED EVENT
flow-c1 transactions send ./cadence/transactions/evm/deploy.cdc \
    --args-json "$(cat ./cadence/args/deploy-factory-args.json)"

# Deploy initial bridge contracts
flow-c1 accounts add-contract ./cadence/contracts/bridge/BridgePermissions.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/ICrossVM.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/CrossVMNFT.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeConfig.cdc