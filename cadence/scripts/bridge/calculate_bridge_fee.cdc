import "FlowEVMBridgeUtils"

/// Returns the calculated fee based on the number of bytes used to escrow an asset plus the base fee.
///
/// @param bytes: The number of bytes used to escrow an asset.
///
/// @return The calculated fee to be paid in FlowToken
///
access(all)
fun main(bytes used: UInt64): UFix64 {
    return FlowEVMBridgeUtils.calculateBridgeFee(bytes: used)
}
