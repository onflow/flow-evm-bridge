flow transactions send ./cadence/transactions/example-assets/setup_collection.cdc --signer user
flow transactions send ./cadence/transactions/example-assets/mint_nft.cdc f3fcd2c1a78f5eee example description thumbnail '[]' '[]' '[]' --signer example-nft

# Deploy ExampleERC721 contract with erc721's COA as owner
flow transactions send ./cadence/transactions/evm/deploy.cdc --args-json "$(cat deploy-erc721-args.json)" --signer erc721

# Mint an ERC721 with ID 42 to the user's COA
flow transactions send ./cadence/transactions/evm/call.cdc \
    d69e40309a188ee9007da49c1cec5602d7f9d767 \
    cd279c7c000000000000000000000000000000000000000000000000000000000000001b000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000003b62616679626569676479727a74357366703775646d37687537367568377932366e6633656675796c71616266336f636c67747179353566627a64690000000000 \
    12000000 0.0 --signer erc721
