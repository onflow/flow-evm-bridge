flow-c1 transactions send ./cadence/transactions/example-assets/setup_collection.cdc --signer user
flow-c1 transactions send ./cadence/transactions/example-assets/mint_nft.cdc f3fcd2c1a78f5eee example description thumbnail '[]' '[]' '[]' --signer example-nft

# Deploy ExampleERC721 contract with erc721's COA as owner
flow-c1 transactions send ./cadence/transactions/evm/deploy.cdc --args-json "$(cat deploy-erc721-args.json)" --signer erc721

# Mint an ERC721 with ID 42 to the user's COA
flow-c1 transactions send ./cadence/transactions/evm/call.cdc \
    74b09a4e4d809b8a4dd58f92ec74a879e6542f60 \
    0000000000000000000000000000000000000000000000024636fdccbbaa9977000000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000077465737455524900000000000000000000000000000000000000000000000000 \
    12000000 0.0 --signer erc721
