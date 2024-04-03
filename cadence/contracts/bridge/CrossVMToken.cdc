import "FungibleToken"

import "EVM"

/// Contract defining cross-VM Fungible Token Vault interface
///
access(all) contract CrossVMToken {

    /// Interface for a Fungible Token Vault with a corresponding ERC20 contract on EVM
    access(all) resource interface EVMFTVault: FungibleToken.Vault {
        /// The ERC20 name value
        access(all) let name: String
        /// The ERC20 symbol value
        access(all) let symbol: String
        /// The ERC20 decimals value
        access(all) let decimals: UInt8

        /// Get the EVM contract address of the corresponding ERC20 contract address
        access(all) view fun getEVMContractAddress(): EVM.EVMAddress
    }
}
