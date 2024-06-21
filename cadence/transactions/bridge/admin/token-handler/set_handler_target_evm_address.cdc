import "EVM"

import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeConfig"

/// Sets the target EVM address for the associated type in the configured TokenHandler
///
/// @param targetTypeIdentifier: The identifier of the target type.
/// @param targetEVMAddressHex: The EVM address of the target EVM contract.
///
transaction(targetTypeIdentifier: String, targetEVMAddressHex: String) {

    let admin: auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeConfig.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeConfig.Admin>(
                from: FlowEVMBridgeConfig.adminStoragePath
            ) ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
    }

    execute {
        let targetType = CompositeType(targetTypeIdentifier)
            ?? panic("Invalid Type identifier provided")
        let targetEVMAddress = EVM.addressFromString(targetEVMAddressHex)
        self.admin.setHandlerTargetEVMAddress(
            targetType: targetType,
            targetEVMAddress: targetEVMAddress
        )
    }
}
