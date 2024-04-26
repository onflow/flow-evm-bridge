import "EVM"

import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeHandlers"
import "FlowEVMBridgeConfig"

/// Sets the minter
///
/// @param vaultIdentifier: The type identifier of the vault to create the TokenHandler for
/// @param minterStoragePath: The type identifier of the TokenMinter implementing resource
///
transaction(vaultIdentifier: String, minterStoragePath: StoragePath, adminAddress: Address) {

    let configAdmin: &FlowEVMBridgeConfig.Admin
    let minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}

    prepare(signer: auth(LoadValue) &Account) {
        self.configAdmin = getAccount(adminAddress).capabilities.borrow<&FlowEVMBridgeConfig.Admin>(
                FlowEVMBridgeConfig.adminPublicPath
            ) ?? panic("Could not borrow reference to FlowEVMBridgeConfig.Admin")
        self.minter <- signer.storage.load<@{FlowEVMBridgeHandlerInterfaces.TokenMinter}>(from: minterStoragePath)
            ?? panic("No minter found at provided storage path")
    }

    execute {
        let targetType = CompositeType(vaultIdentifier)
            ?? panic("Invalid vault identifier")
        self.configAdmin.setTokenHandlerMinter(targetType: targetType, minter: <-self.minter)
    }
}
