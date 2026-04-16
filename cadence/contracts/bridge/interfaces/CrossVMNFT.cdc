import "NonFungibleToken"
import "FungibleToken"
import "MetadataViews"

import "EVM"

import "ICrossVMAsset"

/// Contract defining cross-VM NFT-related interfaces
///
access(all) contract CrossVMNFT {


    /// A simple interface for an NFT that is bridged to the EVM. This may be necessary in some cases as there is
    /// discrepancy between Flow NFT standard IDs (UInt64) and EVM NFT standard IDs (UInt256). Discrepancies on IDs
    /// gone unaccounted for have the potential to induce loss of ownership bridging between VMs, so it's critical to
    /// retain identifying token information on bridging.
    ///
    /// See discussion https://github.com/onflow/flow-nft/pull/126#discussion_r1462612559 where @austinkline raised
    /// differentiating IDs in a minimal interface incorporated into the one below
    ///
    access(all) resource interface EVMNFT : ICrossVMAsset.AssetInfo, NonFungibleToken.NFT {
        access(all) let evmID: UInt256

        access(all) view fun getName(): String
        access(all) view fun getSymbol(): String
        access(all) view fun getEVMContractAddress(): EVM.EVMAddress
        access(all) fun tokenURI(): String
    }

    /// A simple interface for a collection of EVMNFTs
    ///
    access(all) resource interface EVMNFTCollection : NonFungibleToken.Collection {
        access(all) view fun getName(): String
        access(all) view fun getSymbol(): String
        access(all) view fun getEVMIDs(): [UInt256]
        access(all) view fun getCadenceID(from evmID: UInt256): UInt64?
        access(all) view fun getEVMID(from cadenceID: UInt64): UInt256?
        access(all) fun contractURI(): String?
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
