# [WIP] Flow EVM Bridge

> :warning: This repo is a work in progress :building_construction:

This repo contains contracts enabling bridging of fungible & non-fungible assets between Cadence and EVM.

## Deploying Bridge Contracts Locally

As the bridge contracts are still in development, builders should be aware that interfaces may change. If you would like to participate in early development, below are the steps to deploy the bridge contracts to your local emulator environment.

### Prerequisites

Install an EVM-compatible pre-release version of the Flow CLI (currently [v1.12.0-cadence-v1.0.0-M8-2](https://github.com/onflow/flow-cli/releases/tag/v1.12.0-cadence-v1.0.0-M8-2)):

```sh
sudo sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)" \
    -- v1.12.0-cadence-v1.0.0-M8-2
```

If you wish to interact with the contracts from the EVM side, this repo is configured for use with Foundry. See [Foundry's installation docs](https://book.getfoundry.sh/getting-started/installation) for more information.

### Setup

1. Clone this repo and navigate to the root directory.

2. Start the emulator with EVM enabled

```sh
flow-c1 emulator --evm-enabled
```

3. (Optional) If you would like to interact with Flow EVM via the EVM RPC gateway (e.g. via Hardhat, Foundry, etc.), run the gateway locally

> :information_source: Running the gateway enables you to interact with your emulator instance via traditional EVM tooling. More information about the Flow EVM Gateway can be found [here](https://github.com/onflow/flow-evm-gateway)

```sh
flow-c1 evm gateway --coa-address f8d6e0586b0a20c7 --coinbase 0000000000000000000000025521cbccbbaa9977 --coa-key fe809cc837ddcd7e761a482721c050aae43657448db859f4eb8fc421e9609938 --network emulator
```

4. Execute the first setup script
   
```sh
sh local/setup_emulator.1.sh
```

5. Note the last `deployedContractAddress` field in a `evm.TransactionExecuted` event emitted by a deployment transaction executed in the setup script. Got into [`setup_emulator.2.sh`](./local/setup_emulator.2.sh) and replace the first command's argument with the value. Then run the second setup script.

```sh
sh local/setup_emulator.2.sh
```

6. Note the `deployedContractAddress` emitted by the last command in the second script. This is an ERC721 contract deployed by the `erc721` Flow account (as named in the [`flow.json`](./flow.json)). We'll use this address in the last command with one other address. The last command we execute will give us an EVM-native ERC721 minted to the `user` account as named in the [`flow.json`](./flow.json). But first we need to get the COA address owned by the `user` account. Run the following script to get the user's COA's EVM address:

```sh
flow-c1 scripts execute ./cadence/scripts/evm/get_evm_address_string.cdc f3fcd2c1a78f5eee
```

7. To mint the EVM-native ERC721 to the `user` account, run the following script with the `deployedContractAddress` from the second setup script and the COA address from the previous step:

```sh
flow-c1 transactions send ./cadence/transactions/example-assets/safe_mint_erc721.cdc \
    <USER_COA_ADDRESS> 42 "URI" <ERC721_DEPLOYED_CONTRACT_ADDRESS> 200000 \
    --signer erc721
```

You now have all bridge contracts deployed, and a user account with an `ExampleNFT` Cadence NFT minted to it and an `ExampleERC721` EVM-native ERC721 minted to its COA. If you've run the gateway, you can call to the ERC721 address to get the owner of the minted NFT ID (42 in the last command).

```sh
cast call --rpc-url 127.0.0.1:3000 0x<ERC721_DEPLOYED_CONTRACT_ADDRESS> "ownerOf(uint256)" 42
```

The result should be the COA address returned when you queried the `user` account's COA address. To get the NFT ID of the Cadence NFT minted to the `user`, run the following script which queries the `user`'s Flow account to check the Collection for the NFT IDs contained within it.

```sh
flow-c1 scripts execute cadence/scripts/nft/get_ids.cdc f3fcd2c1a78f5eee cadenceExampleNFTCollection
```

### Bridging

The user has some NFTs to bridge and the bridge is now running, so let's get started.

1. Onboard `ExampleNFT` to the bridge. This will deploy a corresponding ERC721 in EVM from which the bridge's owning COA can mint & escrow tokens. To do this, we run the [`onboard_by_type.cdc` transaction](./cadence/transactions/bridge/onboard_by_type.cdc) and provide the Cadence type identifier of the NFT we want to onboard.

```sh
flow-c1 transactions send cadence/transactions/bridge/onboard_by_type.cdc \
    'A.179b6b1cb6755e31.ExampleNFT.NFT' \
    --signer user
```

2. Now that the `ExampleNFT` is onboarded, we can bridge the NFT from Cadence to EVM. To do this, we run the [`bridge_nft_to_evm.cdc` transaction](./cadence/transactions/bridge/bridge_nft.cdc) and provide the NFT contract address, contract name, and ID we want to bridge. Refer to the `get_ids.cdc` script we ran above in the [setup](#setup) section to get the NFT ID.

```sh
flow-c1 transactions send cadence/transactions/bridge/bridge_nft_to_evm.cdc \
    0x179b6b1cb6755e31 ExampleNFT <USERS_NFT_ID> \
    --signer user
```

3. Several events signify the bridging was successful, namely the `A.f8d6e0586b0a20c7.FlowEVMBridge.BridgedNFTToEVM` event which contains the type, ID, ERC721 ID, recipient and EVM defining ERC721 contract address. Let's validate the owner of that NFT with another call to the gateway, referencing the emitted event values for the command below:

```sh
cast call --rpc-url 127.0.0.1:3000 <EVM_CONTRACT_ADDRESS_VALUE> "ownerOf(uint256)" <EVM_ID_VALUE>
```

4. The result should be the `user` account's COA address. Let's now bridge back to Cadence with the [`bridge_nft_from_evm.cdc` transaction](./cadence/transactions/bridge/bridge_nft_from_evm.cdc) with arguments very similar to bridging to EVM.

```sh
flow-c1 transactions send cadence/transactions/bridge/bridge_nft_from_evm.cdc \
    0x179b6b1cb6755e31 ExampleNFT <EVM_NFT_ID> \
    --signer user
```

We should now see several more events including `A.f8d6e0586b0a20c7.FlowEVMBridge.BridgedNFTFromEVM` which informs us of the type, id, EVM ID, calling COA EVM Address, and ERC721 contract Address associated with the bridge request. Note that the Flow account Address isn't returned, since the resource-oriented nature of NFTs in Cadence means the bridge doesn't know the identity of the caller in Cadence. However, the successive `A.f8d6e0586b0a20c7.NonFungibleToken.Deposited` method identifies the bridged NFT ID and the recipient account as `0xf3fcd2c1a78f5eee`.

And that's it! Bridging an ERC721 from EVM to Cadence is largely similar with the exception that onboarding is conducted via the contract's EVM address since that's how the NFT is identified. See the [`onboard_by_evm_address.cdc` transaction](./cadence/transactions/bridge/onboard_by_evm_address.cdc) for what that looks like.

## References

This repo is working on the basis of the design laid out in [FLIP #237](https://github.com/onflow/flips/pull/233).

### Additional Resource

For the current state of Flow EVM across various task paths, see the following resources:

- [Flow EVM Equivalence forum post](https://forum.flow.com/t/evm-equivalence-on-flow-proposal-and-path-forward/5478)
- [EVM Integration FLIP #223](https://github.com/onflow/flips/pull/225/files)
- [Gateway & JSON RPC FLIP #235](https://github.com/onflow/flips/pull/235)