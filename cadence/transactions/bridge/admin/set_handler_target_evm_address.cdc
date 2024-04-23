import "EVM"

import "EVMUtils"
import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeConfig"

/// Sets the base fee charged for all bridge requests.
///
/// @param newFee: The new base fee to charge for all bridge requests.
///
/// @emits FlowEVMBridgeConfig.BridgeFeeUpdated(old: FlowEVMBridgeConfig.onboardFee, new: newFee, isOnboarding: false)
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
        let targetEVMAddress = EVMUtils.getEVMAddressFromHexString(address: targetEVMAddressHex)
            ?? panic("Invalid EVM Address provided")
        self.admin.setHandlerTargetEVMAddress(
            targetType: targetType,
            targetEVMAddress: targetEVMAddress
        )
    }
}
