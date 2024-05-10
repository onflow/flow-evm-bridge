![Tests](https://github.com/onflow/flow-evm-bridge/actions/workflows/cadence_test.yml/badge.svg)
[![codecov](https://codecov.io/gh/onflow/flow-evm-bridge/graph/badge.svg?token=C1vCK0t88F)](https://codecov.io/gh/onflow/flow-evm-bridge)

# Flow EVM Bridge

> :warning: Upcoming breaking changes may result in updated deployment addresses and redirection of bridge requests.

This repo contains contracts enabling bridging of fungible & non-fungible tokens between Cadence and EVM.

## Deployments

PreviewNet is currently the only EVM-enabled network on Flow. The bridge in this repo are deployed to the following
addresses:

|Contracts|PreviewNet|Testnet|Mainnet|
|---|---|---|---|
|All Cadence Bridge contracts|`0x715c57f7a59bc39b`|TBD|TBD|
|[`FlowEVMBridgeFactory.sol`](./solidity/src/FlowBridgeFactory.sol)|`0xf23c8619603434f7f71659820193c8e491feb1d9`|TBD|TBD|
|[`FlowEVMBridgeDeploymentRegistry.sol`](./solidity/src/FlowEVMBridgeDeploymentRegistry.sol)|`0x544ef4ed9209ebe6989bed9e543632512afb25de`|TBD|TBD|
|[`FlowEVMBridgedERC20Deployer.sol`](./solidity/src/FlowEVMBridgedERC20Deployer.sol)|`0xc5577d2935ef0556b37358d8b92aa578f1e7564e`|TBD|TBD|
|[`FlowEVMBridgedERC721Deployer.sol`](./solidity/src/FlowEVMBridgedERC721Deployer.sol)|`0xd5bf043e8d5e6e007ebfdefebef7f4c96de5d40a`|TBD|TBD|

## Interacting with the bridge

> :information_source: All bridging activity in either direction is orchestrated via Cadence on `CadenceOwnedAccount`
> (COA) resources. This means that all bridging activity must be initiated via a Cadence transaction, not an EVM
> transaction regardless of the directionality of the bridge request. For more information on the interplay between
> Cadence and EVM, see [EVM Integration FLIP #223](https://github.com/onflow/flips/pull/225/files)

### Overview

The Flow EVM bridge allows both fungible and non-fungible tokens to move atomically between Cadence and EVM. In the
context of EVM, fungible tokens are defined as ERC20 tokens, and non-fungible tokens as ERC721 tokens. In Cadence,
fungible tokens are defined by contracts implementing FungibleToken and non-fungible tokens the NonFungibleToken
standard contract interfaces.

Like all operations on Flow, there are native fees associated with both computation and storage. To prevent spam and
sustain the bridge account's storage consumption, fees are charged for both onboarding assets and bridging assets. In
the case where storage consumption is expected, fees are charges based on the storage consumed at the current network
rates. In all cases, there is a flat-rate fee in addition to any storage fees.

### Onboarding

Since a contract must define the asset in the target VM, an asset must be "onboarded" to the bridge before requests can
be fulfilled. Moving from Cadence to EVM, onboarding can occur on the fly, deploying a template contract in the same
transaction as the asset is bridged to EVM if the transaction so specifies. Moving from EVM to Cadence, however,
requires that onboarding occur in a separate transaction due to the fact that a Cadence contract is initialized at the
end of a transaction and isn't available in the runtime until after the transaction has executed.

Below are transactions relevant to onboarding assets:
- [`onboard_by_type.cdc`](./cadence/transactions/bridge/onboarding/onboard_by_type.cdc)
- [`onboard_by_evm_address.cdc`](./cadence/transactions/bridge/onboarding/onboard_by_evm_address.cdc)


### Bridging

Once an asset has been onboarded, either by its Cadence type or EVM contract address, it can be bridged in either
direction referred to by its Cadence type. For Cadence-native assets, this is simply its native type. For EVM-native
assets, this is in most cases a templated Cadence contract deployed to the bridge account, the name of which is derived
from the EVM contract address. For instance, an ERC721 contract at address `0x1234` would be onboarded to the bridge as
`EVMVMBridgedNFT_0x1234`, making its type identifier `A.<BRIDGE_ADDRESS>.EVMVMBridgedNFT_0x1234.NFT`.

However, the derivation of these identifiers can be abstracted within transactions. For example, calling applications 
can provide the defining contract address and name of the bridged asset (see
[`bridge_nft_to_evm.cdc`](./cadence/transactions/bridge/nft/bridge_nft_to_evm.cdc)). Alternatively, the defining EVM
contract could be provided, etc - this flexibility is thanks to Cadence's scripted transactions.

#### NFTs

Any Cadence NFTs bridging to EVM are escrowed in the bridge account and either minted in a bridge-deployed ERC721
contract or transferred from escrow to the calling COA in EVM. On the return trip, NFTs are escrowed in EVM - owned by
the bridge's COA - and either unlocked from escrow if locked or minted from a bridge-owned NFT contract.

Below are transactions relevant to bridging NFTs:
- [`bridge_nft_to_evm.cdc`](./cadence/transactions/bridge/nft/bridge_nft_to_evm.cdc)
- [`bridge_nft_from_evm.cdc`](./cadence/transactions/bridge/nft/bridge_nft_from_evm.cdc)

#### Fungible Tokens

Any Cadence fungible tokens bridging to EVM are escrowed in the bridge account only if they are Cadence-native. If the
bridge defines the tokens, they are burned. On the return trip the pattern is similar, with the bridge burning
bridge-defined tokens or escrowing them if they are EVM-native. In all cases, if the bridge has authority to mint on one
side, it must escrow on the other as the native VM contract is owned by an external party.

With fungible tokens in particular, there may be some cases where the Cadence contract is not deployed to the bridge
account, but the bridge still follows a mint/burn pattern in Cadence. These cases are handled via
[`TokenHandler`](./cadence/contracts/bridge/interfaces/FlowEVMBridgeHandlerInterfaces.cdc) implementations. Also know
that moving $FLOW to EVM is built into the `EVMAddress` object so any requests bridging $FLOW to EVM will simply
leverage this interface; however, moving $FLOW from EVM to Cadence must be done through the COA resource.

Below are transactions relevant to bridging fungible tokens:
- [`bridge_tokens_to_evm.cdc`](./cadence/transactions/bridge/ft/bridge_tokens_to_evm.cdc)
- [`bridge_tokens_from_evm.cdc`](./cadence/transactions/bridge/ft/bridge_tokens_from_evm.cdc)


## Prep Your Assets for Bridging

### Context

To maximize utility to the ecosystem, this bridge is permissionless and open to any fungible or non-fungible token as
defined by the respective Cadence standards and limited to ERC20 and ERC721 Solidity standards. Ultimately, a project
does not have to do anything for users to be able to bridge their assets between VMs. However, there are some
considerations developers may take to enhance the representation of their assets in non-native VMs. These largely relate
to asset metadata and ensuring that bridging does not compromise critical user assumptions about asset ownership.

### EVMBridgedMetadata

Proposed in [@onflow/flow-nft/pull/203](https://github.com/onflow/flow-nft/pull/203), the `EVMBridgedMetadata` view
presents a mechanism to both represent metadata from bridged EVM assets as well as enable Cadence-native projects to
specify the representation of their assets in EVM. Implementing this view is not required for assets to be bridged, but
the bridge does default to it when available as a way to provide projects greater control over their EVM asset
definitions within the scope of ERC20 and ERC721 standards.

The interface for this view is as follows:

```cadence
access(all) struct URI: MetadataViews.File {
    /// The base URI prefix, if any. Not needed for all URIs, but helpful
    /// for some use cases For example, updating a whole NFT collection's
    /// image host easily
    access(all) let baseURI: String?
    /// The URI string value
    /// NOTE: this is set on init as a concatenation of the baseURI and the
    /// value if baseURI != nil
    access(self) let value: String

    access(all) view fun uri(): String
        
}

access(all) struct EVMBridgedMetadata {
    access(all) let name: String
    access(all) let symbol: String

    access(all) let uri: {MetadataViews.File}
}
```

This uri value could be a pointer to some offchain metadata if you expect your metadata to be static. Or you could
couple the `uri()` method with the utility contract below to serialize the onchain metadata on the fly.

### SerializeMetadata

The key consideration with respect to metadata is the distinct metadata storage patterns between ecosystem. It's
critical for NFT utility that the metadata be bridged in addition to the representation of the NFTs ownership. However,
it's commonplace for Cadence NFTs to store metadata onchain while EVM NFTs often store an onchain pointer to metadata
stored offchain. In order for Cadence NFTs to be properly represented in EVM platforms, the metadata must be bridged in
a format expected by those platforms and be done in a manner that also preserves the atomicity of bridge requests. The
path forward on this was decided to be a commitment of serialized Cadence NFT metadata into formats popular in the EVM
ecosystem.

For assets that do not implement `EVMBridgedMetadata`, the bridge will attempt to serialize the metadata of the asset as
a JSON data URL string. This is done via the [`SerializeMetadata`
contract](./cadence/contracts/utils/SerializeMetadata.cdc) which serializes metadata values into a JSON blob compatible
with the OpenSea metadata standard. The serialized metadata is then committed as the ERC721 `tokenURI` upon bridging
Cadence-native NFTs to EVM. Since Cadence NFTs can easily update onchain metadata either by field or by the ownership of
sub-NFTs, this serialization pattern enables token URI updates on subsequent bridge requests.

### Opting Out

It's also recognized that the logic of some use cases may actually be compromised by the act of bridging, particularly
in such a unique runtime environment. These would be cases that do not maintain ownership assumptions implicit to
ecosystem standards. For instance, an ERC721 implementation may reclaim a user's assets after a month of inactivity time
period. In such a case, bridging that ERC721 to Cadence would decouple the representation of ownership of the bridged
NFT from the actual ownership in the definining ERC721 contract after the token had been reclaimed - there would be no
NFT in escrow for the bridge to transfer on fulfillment of the NFT back to EVM. In such cases, projects may choose to
opt-out of bridging, but **importantly must do so before the asset has been onboarded to the bridge**.

For Solidity contracts, opting out is as simple as extending the [`BridgePermissions.sol` abstract
contract](./solidity/src/interfaces/BridgePermissions.sol) which defaults `allowsBridging()` to false. The bridge explicitly checks
for the implementation of `IBridgePermissions` and the value of `allowsBridging()` to validate that the contract has not
opted out of bridging.

Similarly, Cadence contracts can implement the [`IBridgePermissions.cdc` contract
interface](./cadence/contracts/bridge/interfaces/IBridgePermissions.cdc). This contract has a single method
`allowsBridging()` with a default implementation returning `false`. Again, the bridge explicitly checks for the
implementation of `IBridgePermissions` and the value of `allowsBridging()` to validate that the contract has not opted
out of bridging. Should you later choose to enable bridging, you can simply override the default implementation and
return true.

In both cases, `allowsBridging()` gates onboarding to the bridge. Once onboarded - **a permissionless operation anyone can
execute** - the value of `allowsBridging()` is irrelevant and assets can move between VMs permissionlessly.

## Under the Hood

For an in-depth look at the high-level architecture of the bridge, see [FLIP
#237](https://github.com/onflow/flips/pull/233)

### Additional Resources

For the current state of Flow EVM across various task paths, see the following resources:

- [Flow EVM Equivalence forum post](https://forum.flow.com/t/evm-equivalence-on-flow-proposal-and-path-forward/5478)
- [EVM Integration FLIP #223](https://github.com/onflow/flips/pull/225/files)
- [Gateway & JSON RPC FLIP #235](https://github.com/onflow/flips/pull/235)