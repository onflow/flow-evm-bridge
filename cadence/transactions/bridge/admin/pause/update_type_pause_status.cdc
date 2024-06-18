import "FlowEVMBridgeConfig"

/// Sets the pause status of the specified asset type as either paused or unpaused.
///
/// @param typeIdentifier: The type identifier of the asset to pause or unpause.
/// @param pause: A boolean indicating whether the FlowEVM Bridge should be paused or unpaused.
///
/// @emits FlowEVMBridgeConfig.TypePauseStatusUpdated(paused: true)
///
transaction(typeIdentifier: String, pause: Bool) {

    let admin: auth(FlowEVMBridgeConfig.Pause) &FlowEVMBridgeConfig.Admin
    let type: Type

    prepare(signer: auth(BorrowValue) &Account) {
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeConfig.Pause) &FlowEVMBridgeConfig.Admin>(from: FlowEVMBridgeConfig.adminStoragePath)
            ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
        self.type = CompositeType(typeIdentifier) ?? panic("Invalid type identifier provided: ".concat(typeIdentifier))
    }

    execute {
        if pause {
            self.admin.pauseType(self.type)
        } else {
            self.admin.unpauseType(self.type)
        }
    }

    post {
        FlowEVMBridgeConfig.isTypePaused(self.type) == pause: "Problem updating pause status for provided type"
    }
}
