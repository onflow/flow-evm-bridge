import "FlowEVMBridge"

/// Returns whether a type needs to be onboarded to the FlowEVMBridge
///
/// @param type: The Cadence Type in question
///
/// @return Whether the type requires onboarding to the FlowEVMBridge if the type is bridgeable, otherwise nil
///
access(all) fun main(type: Type): Bool? {
    return FlowEVMBridge.typeRequiresOnboarding(type)
}
