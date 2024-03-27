import "NonFungibleToken"
import "FungibleToken"
import "MetadataViews"

import "EVM"

/// Contract defining cross-VM FT & Vault interfaces
///
access(all)
contract CrossVMFT {

    /// Proof of concept metadata to represent the ERC721 values of the NFT
    ///
    // TODO: What data is there about an FT that's needed on the evm side?
    access(all)
    struct EVMBridgedMetadata {
        /// The name of the FFT
        access(all)
        let name: String
        /// The symbol of the FT
        access(all)
        let symbol: String
        /// The URI of the NFT - this can either be contract-level or token-level URI depending on where the metadata
        /// is requested. See the ViewResolver contract interface to discover how contract & resource-level metadata
        /// requests are handled.
        access(all)
        let uri: {MetadataViews.File}

        init(name: String, symbol: String, uri: {MetadataViews.File}) {
            self.name = name
            self.symbol = symbol
            self.uri = uri
        }
    }

}
