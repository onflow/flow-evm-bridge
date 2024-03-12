flow-c1 transactions send ./cadence/transactions/example-assets/setup_collection.cdc --signer user
flow-c1 transactions send ./cadence/transactions/example-assets/mint_nft.cdc f3fcd2c1a78f5eee example description thumbnail '[]' '[]' '[]' --signer example-nft

# Deploy ExampleERC721 contract with erc721's COA as owner
flow-c1 transactions send ./cadence/transactions/evm/deploy.cdc --args-json "$(cat deploy-erc721-args.json)" --signer erc721

# Mint an ERC721 with ID 42 to the user's COA
flow-c1 transactions send ./cadence/transactions/example-assets/safe_mint_erc721.cdc \
    0000000000000000000000024b74bbccbbaa9977 42 "URI" 50215a38d89c385841f50602c5af2e0acfd30319 200000 \
    --signer erc721
