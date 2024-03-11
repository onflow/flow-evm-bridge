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
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeUtils.cdc 8573d223ca2b9ec87d5efd69649c264afdac6c0e
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeNFTEscrow.cdc
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeTemplates.cdc
# Add the templated contract code chunks for FlowEVMBridgedNFTTemplate.cdc contents
low-c1 transactions send ./cadence/transactions/bridge/admin/upsert_contract_code_chunks.cdc --args-json "$(cat ./bridged-nft-code-chunks-args.json)" --gas-limit 1600

flow-c1 accounts add-contract ./cadence/contracts/bridge/IEVMBridgeNFTMinter.cdc


# Deploy main bridge contract - Will break flow.json config due to bug in CLI - break here and update flow.json manually
flow-c1 accounts add-contract ./cadence/contracts/bridge/FlowEVMBridge.cdc f8d6e0586b0a20c7

# Then manually enter the command & continue with setup_emulator.2.sh
# Deploy the bridge router directing calls from COAs to the dedicated bridge
# flow-c1 accounts add-contract ./cadence/contracts/bridge/EVMBridgeRouter.cdc f8d6e0586b0a20c7