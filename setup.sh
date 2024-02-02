#!/bin/bash

sh pass_precompiles.sh

# Deploy initial bridge contracts
flow accounts add-contract ./cadence/contracts/bridge/ICrossVM.cdc
flow accounts add-contract ./cadence/contracts/bridge/CrossVMNFT.cdc
flow accounts add-contract ./cadence/contracts/bridge/IFlowEVMNFTBridge.cdc
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeConfig.cdc
flow accounts add-contract ./cadence/contracts/bridge/IEVMBridgeNFTLocker.cdc

# Create COA in emulator-account
flow evm create-account 100.0

# Deploy the Factory contract in EVM - the address is required by the FlowEVMBridgeUtils contract
flow transactions send ./cadence/transactions/evm/deploy.cdc --args-json "$(cat deploy-factory-args.json)"

# Provided address is the address of the Factory contract deployed in the previous txn
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeUtils.cdc 9ca416871ee388c7a41e0b7886dfcc47e08bbdef
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridgeTemplates.cdc

# Deploy main bridge contract
flow accounts add-contract ./cadence/contracts/bridge/FlowEVMBridge.cdc

# Create `example-nft` account 179b6b1cb6755e31 with private key 96dfbadf086daa187100a24b1fd2b709b702954bbd030a394148e11bcbb799ef
flow accounts create --key "351e1310301a7374430f6077d7b1b679c9574f8e045234eac09568ceb15c4f5d937104b4c3180df1e416da20c9d58aac576ffc328a342198a5eae4a29a13c47a"

# Create `user` account 0xf3fcd2c1a78f5eee with private key bce84aae316aec618888e5bdd24a3c8b8af46896c1ebe457e2f202a4a9c43075
flow accounts create --key "c695fa608bd40821552fae13bb710c917309690ed69c22866abad19d276c99296379358321d0123d7074c817dd646ae8f651734526179eaed9f33eba16601ff6"

# Create `erc721` account 0xe03daebed8ca0615 with private key bf602a4cdffb5610a008622f6601ba7059f8a6f533d7489457deb3d45875acb0
flow accounts create --key "9103fd9106a83a2ede667e2486848e13e5854ea512af9bbec9ad2aec155bd5b5c146b53a6c3fd619c591ae0cd730acb875e5b6e074047cf31d620b53c55a4fb4"

# Give the user some FLOW
flow transactions send ./cadence/transactions/flow-token/transfer_flow.cdc 0xf3fcd2c1a78f5eee 100.0

# Give the erc721 some FLOW
flow transactions send ./cadence/transactions/flow-token/transfer_flow.cdc 0xe03daebed8ca0615 100.0

# Create a COA for the user
flow transactions send ./cadence/transactions/evm/create_account.cdc 10.0 --signer user

# Create a COA for the erc721
flow transactions send ./cadence/transactions/evm/create_account.cdc 10.0 --signer erc721

# user transfers Flow to the COA
flow transactions send ./cadence/transactions/evm/deposit.cdc 10.0 --signer user

# erc721 transfers Flow to the COA
flow transactions send ./cadence/transactions/evm/deposit.cdc 10.0 --signer erc721

# Setup User with Example NFT collection
flow accounts add-contract ./cadence/contracts/example-assets/ExampleNFT.cdc --signer example-nft
flow transactions send ./cadence/transactions/example-assets/setup_collection.cdc --signer user
flow transactions send ./cadence/transactions/example-assets/mint_nft.cdc f3fcd2c1a78f5eee example description thumbnail '[]' '[]' '[]' --signer example-nft

# Deploy ExampleERC721 contract with erc721's COA as owner
flow transactions send ./cadence/transactions/evm/deploy.cdc --args-json "$(cat deploy-erc721-args.json)" --signer erc721

# Mint an ERC721 to the user's COA
flow transactions send ./cadence/transactions/evm/call.cdc \
    d69e40309a188ee9007da49c1cec5602d7f9d767 \
    cd279c7c000000000000000000000000000000000000000000000000000000000000001b000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000003b62616679626569676479727a74357366703775646d37687537367568377932366e6633656675796c71616266336f636c67747179353566627a64690000000000 \
    12000000 0.0 --signer erc721
