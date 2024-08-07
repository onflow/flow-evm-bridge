import "FlowEVMBridgeConfig"

/// Sets the base fee charged for all bridge requests.
///
/// @param newFee: The new base fee to charge for all bridge requests.
///
/// @emits FlowEVMBridgeConfig.BridgeFeeUpdated(old: FlowEVMBridgeConfig.onboardFee, new: newFee, isOnboarding: false)
///
transaction(newFee: UFix64) {

    let admin: auth(FlowEVMBridgeConfig.Fee) &FlowEVMBridgeConfig.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeConfig.Fee) &FlowEVMBridgeConfig.Admin>(
                from: FlowEVMBridgeConfig.adminStoragePath
            ) ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
    }

    execute {
        self.admin.updateBaseFee(newFee)
    }

    post {
        FlowEVMBridgeConfig.baseFee == newFee: "Fee was not set correctly"
    }
}
