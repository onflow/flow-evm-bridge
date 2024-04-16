import "FlowEVMBridgeConfig"

/// Sets the onboarding fee charged to onboard an asset to the bridge.
///
/// @param newFee: The fee paid to onboard an asset.
///
/// @emits FlowEVMBridgeConfig.BridgeFeeUpdated(old: FlowEVMBridgeConfig.onboardFee, new: newFee, isOnboarding: true)
///
transaction(newFee: UFix64) {
    prepare(signer: auth(BorrowValue) &Account) {
        signer.storage.borrow<&FlowEVMBridgeConfig.Admin>(from: FlowEVMBridgeConfig.adminStoragePath)
            ?.updateOnboardingFee(newFee)
            ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
    }
}
