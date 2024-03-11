import "NonFungibleToken"
import "FungibleToken"
import "MetadataViews"

import "EVM"

/// Contract defining cross-VM NFT & Collection interfaces
///
access(all) contract CrossVMNFT {

    /// A struct to represent a general case URI, used to represent the URI of the NFT where the type of URI is not
    /// able to be determined (i.e. HTTP, IPFS, etc.)
    ///
    access(all) struct URI : MetadataViews.File {
        /// The URI value
        access(self) let value: String

        access(all) view fun uri(): String {
            return self.value
        }

        init(_ value: String) {
            self.value = value
        }
    }

    /// Proof of concept metadata to represent the ERC721 values of the NFT
    ///
    access(all) struct EVMBridgedMetadata {
        /// The name of the NFT
        access(all) let name: String
        /// The symbol of the NFT
        access(all) let symbol: String
        /// The URI of the NFT - this can either be contract-level or token-level URI depending on where the metadata
        /// is requested. See the ViewResolver contract interface to discover how contract & resource-level metadata
        /// requests are handled.
        access(all) let uri: {MetadataViews.File}

        init(name: String, symbol: String, uri: {MetadataViews.File}) {
            self.name = name
            self.symbol = symbol
            self.uri = uri
        }
    }

    /// A simple interface for an NFT that is bridged to the EVM. This may be necessary in some cases as there is
    /// discrepancy between Flow NFT standard IDs (UInt64) and EVM NFT standard IDs (UInt256). Discrepancies on IDs
    /// gone unaccounted for have the potential to induce loss of ownership bridging between VMs, so it's critical to
    /// retain identifying token information on bridging.
    ///
    /// See discussion https://github.com/onflow/flow-nft/pull/126#discussion_r1462612559 where @austinkline raised
    /// differentiating IDs in a minimal interface incorporated into the one below
    ///
    access(all) resource interface EVMNFT : NonFungibleToken.NFT {
        access(all) let evmID: UInt256
        access(all) let name: String
        access(all) let symbol: String
        access(all) fun tokenURI(): String
        access(all) fun getEVMContractAddress(): EVM.EVMAddress
    }

    /// A simple interface for a collection of EVMNFTs
    ///
    access(all) resource interface EVMNFTCollection {
        access(all) view fun getEVMIDs(): [UInt256]
        access(all) view fun getCadenceID(from evmID: UInt256): UInt64?
        access(all) view fun getEVMID(from cadenceID: UInt64): UInt256?
        access(all) view fun contractURI(): String?
    }

    /// Retrieves the EVM ID of an NFT if it implements the EVMNFT interface, returning nil if not
    ///
    access(all) view fun getEVMID(from token: &{NonFungibleToken.NFT}): UInt256? {
        if let evmNFT = token as? &{EVMNFT} {
            return evmNFT.evmID
        }
        return nil
    }
}
