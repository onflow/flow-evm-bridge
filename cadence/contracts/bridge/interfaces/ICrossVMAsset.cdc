import "EVM"

import "ICrossVM"

/// A simple contract interface for a Cadence contract that represents an asset bridged from Flow EVM such as an ERC20
/// or ERC721 token.
///
access(all) contract interface ICrossVMAsset : ICrossVM {
    /// Returns the name of the asset
    access(all) view fun getName(): String
    /// Returns the symbol of the asset
    access(all) view fun getSymbol(): String

    access(all) resource interface AssetInfo {
        access(all) view fun getName(): String
        access(all) view fun getSymbol(): String
        access(all) view fun getEVMContractAddress(): EVM.EVMAddress        
    }
}
