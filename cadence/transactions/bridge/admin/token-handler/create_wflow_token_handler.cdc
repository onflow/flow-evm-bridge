import "FlowToken"

import "EVM"

import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeHandlers"

/// Creates a WFLOWTokenHandler for moving FLOW between VMs. The TokenHandler is configured in the bridge to handle the 
/// FlowToken Vault type.
///
/// @param wflowEVMAddressHex: The EVM address of the WFLOW contract as a hex string
///
transaction(wflowEVMAddressHex: String) {

    let configurator: auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeHandlers.HandlerConfigurator

    prepare(signer: auth(BorrowValue, LoadValue) &Account) {
        self.configurator = signer.storage.borrow<auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeHandlers.HandlerConfigurator>(
                from: FlowEVMBridgeHandlers.ConfiguratorStoragePath
            ) ?? panic("Missing configurator")
    }

    execute {
        let wflowEVMAddress = EVM.addressFromString(wflowEVMAddressHex)
        self.configurator.createTokenHandler(
            handlerType: Type<@FlowEVMBridgeHandlers.WFLOWTokenHandler>(),
            targetType: Type<@FlowToken.Vault>(),
            targetEVMAddress: wflowEVMAddress,
            expectedMinterType: nil
        )
    }
}
