import "FlowEVMBridgeConfig"

/// Returns the current onboard fee for onboarding an asset to the bridge
///
/// @return The onboard fee to be paid in FlowToken
///
access(all)
fun main(): UFix64 {
    return FlowEVMBridgeConfig.onboardFee
}
