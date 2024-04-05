# Mint an ERC721 with ID 42 to the user's COA
flow-c1 transactions send ./cadence/transactions/example-assets/safe_mint_erc721.cdc \
    <REPLACE WITH COA EVM ADDRESS OWNED BY USER> 42 "URI" <REPLACE WITH THE ERC721 ADDRESS DEPLOYED IN LAST STEP> 200000 \
    --signer erc721
