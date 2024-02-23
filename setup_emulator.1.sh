#!/bin/bash

sh pass_precompiles.sh

# Update the emulator deployed EVM contract
flow accounts update-contract ./cadence/contracts/standards/EVM.cdc

# Create COA in emulator-account
flow evm create-account 100.0

# Deploy the Factory contract
flow transactions send ./cadence/transactions/evm/deploy.cdc --args-json "$(cat deploy-factory-args.json)"

# Deploy initial bridge contracts
flow accounts add-contract ./cadence/contracts/bridge/ICrossVM.cdc
flow accounts add-contract ./cadence/contracts/bridge/CrossVMNFT.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeConfig.cdc
# Provided address is the address of the Factory contract deployed in the previous txn
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeUtils.cdc 9ca416871ee388c7a41e0b7886dfcc47e08bbdef
flow accounts add-contract ./cadence/contracts/bridge/IEVMBridgeNFTEscrow.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeNFTEscrow.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeTemplates.cdc

# Deploy main bridge contract - Will break flow.json config due to bug in CLI - break here and update flow.json manually
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridge.cdc f8d6e0586b0a20c7

# Then manually enter the command & continue with setup_emulator.2.sh
# Deploy the bridge router directing calls from COAs to the dedicated bridge
# flow accounts add-contract ./cadence/contracts/bridge/EVMBridgeRouter.cdc f8d6e0586b0a20c7