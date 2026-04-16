import EVM from 0xe467b9dd11fa00df

import ICrossVM from 0x1e4aa0b87d10b141

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
