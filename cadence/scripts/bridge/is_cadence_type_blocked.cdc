import "EVM"

import "FlowEVMBridgeConfig"

/// Returns whether a Cadence Type is blocked from onboarded to the FlowEVMBridge
///
/// @param typeIdentifier: The Cadence Type identifier of the asset in question
///
/// @return Whether the Cadence type is blocked from onboarding to the FlowEVMBridge
///
access(all) fun main(typeIdentifier: String): Bool {
    let type = CompositeType(typeIdentifier) ?? panic("Invalid type identifier ".concat(typeIdentifier))
    return FlowEVMBridgeConfig.isCadenceTypeBlocked(type)
}
