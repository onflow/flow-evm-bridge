#!/bin/bash

sh pass_precompiles.sh

# Deploy initial bridge contracts
flow accounts add-contract ./contracts/bridge/ICrossVM.cdc
flow accounts add-contract ./contracts/bridge/IEVMBridgeNFTLocker.cdc

# Create COA in emulator-account
flow evm create-account 100.0

# Deploy the Factory contract in EVM - the address is required by the FlowEVMBridgeUtils contract
flow transactions send ./transactions/evm/deploy.cdc --args-json "$(cat deploy-factory-args.json)"

# Provided address is the address of the Factory contract deployed in the previous txn
flow accounts add-contract ./contracts/bridge/FlowEVMBridgeUtils.cdc 9ca416871ee388c7a41e0b7886dfcc47e08bbdef
flow accounts add-contract ./contracts/bridge/FlowEVMBridgeTemplates.cdc

# Fund the Utils contract COA
flow evm fund 000000000000000000000000000000000000001b 100.0

# Deploy main bridge contract
flow accounts add-contract ./contracts/bridge/FlowEVMBridge.cdc

# Create `example-nft` account 179b6b1cb6755e31 with private key 96dfbadf086daa187100a24b1fd2b709b702954bbd030a394148e11bcbb799ef
flow accounts create --key "351e1310301a7374430f6077d7b1b679c9574f8e045234eac09568ceb15c4f5d937104b4c3180df1e416da20c9d58aac576ffc328a342198a5eae4a29a13c47a"

# Create user` account 0xf3fcd2c1a78f5eee with private key bce84aae316aec618888e5bdd24a3c8b8af46896c1ebe457e2f202a4a9c43075
flow accounts create --key "c695fa608bd40821552fae13bb710c917309690ed69c22866abad19d276c99296379358321d0123d7074c817dd646ae8f651734526179eaed9f33eba16601ff6"

# Give the user some FLOW
flow transactions send ./transactions/flow-token/transfer_flow.cdc 0xf3fcd2c1a78f5eee 100.0

# Create a COA for the user
flow transactions send ./transactions/evm/create_account.cdc 10.0 --signer user

# User transfers Flow to the COA
flow transactions send ./transactions/evm/deposit.cdc 10.0 --signer user

# Setup User with Example NFT collection
flow accounts add-contract ./contracts/example-assets/ExampleNFT.cdc --signer example-nft
flow transactions send ./transactions/example-assets/setup_collection.cdc --signer user
flow transactions send ./transactions/example-assets/mint_nft.cdc f3fcd2c1a78f5eee example description thumbnail '[]' '[]' '[]' --signer example-nft

# Replace the COA in the emulator-account that was loaded into the bridge contract storage for RPC purposes
flow evm create-account 100.0