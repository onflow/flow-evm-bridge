import "FlowEVMBridgeConfig"

/// Sets the pause status of the FlowEVM Bridge as specified.
///
/// @param pause: A boolean indicating whether the FlowEVM Bridge should be paused or unpaused.
///
/// @emits FlowEVMBridgeConfig.PauseStatusUpdated(paused: true)
///
transaction(pause: Bool) {

    let admin: auth(FlowEVMBridgeConfig.Pause) &FlowEVMBridgeConfig.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeConfig.Pause) &FlowEVMBridgeConfig.Admin>(from: FlowEVMBridgeConfig.adminStoragePath)
            ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
    }

    execute {
        if pause {
            self.admin.pauseBridge()
        } else {
            self.admin.unpauseBridge()
        }
    }
}
