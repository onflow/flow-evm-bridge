![Tests](https://github.com/onflow/flow-evm-bridge/actions/workflows/cadence_test.yml/badge.svg)
[![codecov](https://codecov.io/gh/onflow/flow-evm-bridge/graph/badge.svg?token=C1vCK0t88F)](https://codecov.io/gh/onflow/flow-evm-bridge)

# [WIP] Flow EVM Bridge

> :warning: This repo is a work in progress :building_construction:

This repo contains contracts enabling bridging of fungible & non-fungible assets between Cadence and EVM.

## Deployments

PreviewNet is currently the only EVM-enabled network on Flow. The bridge in this repo are deployed to the following addresses:

|Network|Address|
|---|---|
|PreviewNet|`0x634acef27f871527`|
|Testnet|TBD|
|Mainnet|TBD|

## Interacting with the bridge

<!-- 
### Overview
### Onboarding
### Bridging
- NFTs
- Fungible Tokens
-->

## Prep Your Assets for Bridging

<!--
### Context
### EVMBridgedMetadata
- name
- symbol
- tokenURI
### SerializeMetadata
### Opting Out
-->

## Under the Hood (facilitating cross-vm interactions)

<!--
### Architecture
### Use Case Walkthrough
- Cadence-native NFT
  - to EVM
  - from EVM
- EVM-native ERC721
  - from EVM
  - to EVM
### Call Flows
### Events
- Cadence
- EVM
### API Reference (docgen public methods? FLIX reference?)
 -->

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