import "FlowEVMBridge"

/// Returns whether a type needs to be onboarded to the FlowEVMBridge
///
/// @param Types: The array of types to check for onboarding status
///
/// @return Whether the type requires onboarding to the FlowEVMBridge if the type is bridgeable, otherwise nil indexed
///     on the type
///
access(all) fun main(types: [Type]): {Type: Bool?} {
    let results: {Type: Bool?} = {}
    for type in types {
        if results[type] != nil {
            continue
        }
        results.insert(key: type, FlowEVMBridge.typeRequiresOnboarding(type))
    }
    return results
}
