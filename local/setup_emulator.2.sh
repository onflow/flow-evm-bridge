# Create `example-nft` account 179b6b1cb6755e31 with private key 96dfbadf086daa187100a24b1fd2b709b702954bbd030a394148e11bcbb799ef
flow-c1 accounts create --key "351e1310301a7374430f6077d7b1b679c9574f8e045234eac09568ceb15c4f5d937104b4c3180df1e416da20c9d58aac576ffc328a342198a5eae4a29a13c47a"

# Create `user` account 0xf3fcd2c1a78f5eee with private key bce84aae316aec618888e5bdd24a3c8b8af46896c1ebe457e2f202a4a9c43075
flow-c1 accounts create --key "c695fa608bd40821552fae13bb710c917309690ed69c22866abad19d276c99296379358321d0123d7074c817dd646ae8f651734526179eaed9f33eba16601ff6"

# Create `erc721` account 0xe03daebed8ca0615 with private key bf602a4cdffb5610a008622f6601ba7059f8a6f533d7489457deb3d45875acb0
flow-c1 accounts create --key "9103fd9106a83a2ede667e2486848e13e5854ea512af9bbec9ad2aec155bd5b5c146b53a6c3fd619c591ae0cd730acb875e5b6e074047cf31d620b53c55a4fb4"

# Give the user some FLOW
flow-c1 transactions send ./cadence/transactions/flow-token/transfer_flow.cdc 0xf3fcd2c1a78f5eee 100.0

# Give the erc721 some FLOW
flow-c1 transactions send ./cadence/transactions/flow-token/transfer_flow.cdc 0xe03daebed8ca0615 100.0

# Create a COA for the user
flow-c1 transactions send ./cadence/transactions/evm/create_account.cdc 10.0 --signer user

# Create a COA for the erc721
flow-c1 transactions send ./cadence/transactions/evm/create_account.cdc 10.0 --signer erc721

# user transfers Flow to the COA
flow-c1 transactions send ./cadence/transactions/evm/deposit.cdc 10.0 --signer user

# erc721 transfers Flow to the COA
flow-c1 transactions send ./cadence/transactions/evm/deposit.cdc 10.0 --signer erc721

# Setup User with Example NFT collection - Will break flow.json config due to bug in CLI - break here and update flow.json manually
flow-c1 accounts add-contract ./cadence/contracts/example-assets/ExampleNFT.cdc --signer example-nft