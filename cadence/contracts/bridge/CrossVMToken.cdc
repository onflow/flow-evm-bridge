import "FungibleToken"

import "EVM"

/// Contract defining cross-VM Fungible Token Vault interface
///
access(all) contract CrossVMToken {

    access(all) resource interface EVMFTVault: FungibleToken.Vault {
        access(all) let name: String
        access(all) let symbol: String
        access(all) let decimals: UInt8

        access(all) view fun getEVMContractAddress(): EVM.EVMAddress
    }
}
