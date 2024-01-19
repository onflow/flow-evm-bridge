import "FlowEVMBridge"

/// Returns whether a type needs to be onboarded to the FlowEVMBridge
///
access(all) fun main(identifier: String): Bool? {
    if let type = CompositeType(identifier) {
        return FlowEVMBridge.typeRequiresOnboarding(type)
    }
    return nil
}
