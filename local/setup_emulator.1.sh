#!/bin/bash

flow-c1 accounts update-contract ./cadence/contracts/standards/EVM.cdc

# Create COA in emulator-account
flow-c1 transactions send ./cadence/transactions/evm/create_account.cdc 100.0

# Deploy the Factory contract
flow-c1 transactions send ./cadence/transactions/evm/deploy.cdc --args-json "$(cat deploy-factory-args.json)"

# Deploy initial bridge contracts
flow-c1 accounts add-contract ./cadence/contracts/bridge/BridgePermissions.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/ICrossVM.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/CrossVMNFT.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeConfig.cdc
# Provided address is the address of the Factory contract deployed in the previous txn
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeUtils.cdc a3c8d221ad218f0d61a3987469dc1c7dfa4a1515
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeNFTEscrow.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeTemplates.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/IEVMBridgeNFTMinter.cdc


# Deploy main bridge contract - Will break flow.json config due to bug in CLI - break here and update flow.json manually
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridge.cdc f8d6e0586b0a20c7

# Then manually enter the command & continue with setup_emulator.2.sh
# Deploy the bridge router directing calls from COAs to the dedicated bridge
# flow-c1 accounts add-contract ./cadence/contracts/bridge/EVMBridgeRouter.cdc f8d6e0586b0a20c7