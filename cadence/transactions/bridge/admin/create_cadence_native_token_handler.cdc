import "EVM"

import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeHandlers"

/// Creates a new TokenHandler for a Cadence-native fungible token, pulling a TokenMinter resource from the provided
/// storage path.
///
/// @param vaultIdentifier: The identifier of the vault to create the TokenHandler for
/// @param minterStoragePath: The storage path to load the TokenMinter resource from
///
transaction(vaultIdentifier: String, minterStoragePath: StoragePath) {

    let configurator: auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeHandlers.HandlerConfigurator
    let minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}

    prepare(tokenMinter: auth(LoadValue) &Account, bridge: auth(BorrowValue, LoadValue) &Account) {
        self.configurator = bridge.storage.borrow<auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeHandlers.HandlerConfigurator>(
                from: FlowEVMBridgeHandlers.ConfiguratorStoragePath
            ) ?? panic("Missing configurator")

        self.minter <-tokenMinter.storage.load<@{FlowEVMBridgeHandlerInterfaces.TokenMinter}>(from: minterStoragePath)
            ?? panic("Minter not found at provided path")
    }

    execute {
        let targetType = CompositeType(vaultIdentifier)
            ?? panic("Invalid vault identifier")
        self.configurator.createTokenHandler(
            handlerType: Type<@FlowEVMBridgeHandlers.CadenceNativeTokenHandler>(),
            targetType: targetType,
            targetEVMAddress: nil,
            minter: <-self.minter
        )
    }
}
