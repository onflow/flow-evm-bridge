import "FlowEVMBridgeConfig"

/// Sets the base fee charged for all bridge requests.
///
/// @param newFee: The new base fee to charge for all bridge requests.
///
/// @emits FlowEVMBridgeConfig.BridgeFeeUpdated(old: FlowEVMBridgeConfig.onboardFee, new: newFee, isOnboarding: false)
///
transaction(newFee: UFix64) {
    prepare(signer: auth(BorrowValue) &Account) {
        signer.storage.borrow<&FlowEVMBridgeConfig.Admin>(from: FlowEVMBridgeConfig.adminStoragePath)
            ?.updateBaseFee(newFee)
            ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
    }
}
