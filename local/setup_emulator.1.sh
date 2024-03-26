#!/bin/bash

flow transactions send ./cadence/transactions/evm/create_account.cdc 100.0

flow accounts add-contract ./cadence/contracts/utils/ArrayUtils.cdc
flow accounts add-contract ./cadence/contracts/utils/StringUtils.cdc
flow accounts add-contract ./cadence/contracts/utils/ScopedFTProviders.cdc

flow accounts update-contract ./cadence/contracts/standards/EVM.cdc

# Create COA in emulator-account

# Deploy the Factory contract - NOTE THE `deployedContractAddress` IN THE EMITTED EVENT
flow transactions send ./cadence/transactions/evm/deploy.cdc \
    --args-json "$(cat ./cadence/args/deploy-factory-args.json)"

# Deploy initial bridge contracts
flow accounts add-contract ./cadence/contracts/bridge/BridgePermissions.cdc
flow accounts add-contract ./cadence/contracts/bridge/ICrossVM.cdc
flow accounts add-contract ./cadence/contracts/bridge/CrossVMNFT.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeConfig.cdc