import "EVM"

import "ExampleHandledToken"

import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeHandlers"

transaction {

    let configurator: auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeHandlers.HandlerConfigurator
    let minter: @ExampleHandledToken.Minter

    prepare(tokenMinter: auth(LoadValue) &Account, bridge: auth(BorrowValue, LoadValue) &Account) {
        self.configurator = bridge.storage.borrow<auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeHandlers.HandlerConfigurator>(
                from: FlowEVMBridgeHandlers.ConfiguratorStoragePath
            ) ?? panic("Missing configurator")

        self.minter <-tokenMinter.storage.load<@ExampleHandledToken.Minter>(from: ExampleHandledToken.AdminStoragePath)
            ?? panic("Minter not found at provided path")
    }

    execute {
        self.configurator.createTokenHandler(
            handlerType: Type<@FlowEVMBridgeHandlers.CadenceNativeTokenHandler>(),
            targetType: Type<@ExampleHandledToken.Vault>(),
            targetEVMAddress: nil,
            minter: <-self.minter
        )
    }
}
