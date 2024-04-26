import "FlowEVMBridgeConfig"

/// Pauses bridging operations.
///
/// @emits FlowEVMBridgeConfig.PauseStatusUpdated(paused: true)
///
transaction {
    prepare(signer: auth(BorrowValue) &Account) {
        signer.storage.borrow<auth(FlowEVMBridgeConfig.Pause) &FlowEVMBridgeConfig.Admin>(from: FlowEVMBridgeConfig.adminStoragePath)
            ?.pauseBridge()
            ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
    }
}
