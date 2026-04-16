import FungibleToken from 0xf233dcee88fe0abe

import EVM from 0xe467b9dd11fa00df

/// Contract defining cross-VM Fungible Token Vault interface
///
access(all) contract CrossVMToken {

    /// Interface for a Fungible Token Vault with a corresponding ERC20 contract on EVM
    access(all) resource interface EVMTokenInfo {
        /// Gets the ERC20 name value
        access(all) view fun getName(): String
        /// Gets the ERC20 symbol value
        access(all) view fun getSymbol(): String
        /// Gets the ERC20 decimals value
        access(all) view fun getDecimals(): UInt8
        /// Get the EVM contract address of the corresponding ERC20 contract address
        access(all) view fun getEVMContractAddress(): EVM.EVMAddress
    }
}
