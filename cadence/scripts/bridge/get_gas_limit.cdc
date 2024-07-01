import "FlowEVMBridgeConfig"

/// Returns the gas limit for the Flow-EVM bridge.
///
/// @returns The current gas limit shared by all the bridge-related EVM operations.
///
access(all)
fun main(): UInt64 {
    return FlowEVMBridgeConfig.gasLimit
}
