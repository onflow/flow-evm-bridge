import "FlowEVMBridgeConfig"

/// Returns the gas limit the bridge declares for read-only EVM calls whose cost is bounded by the
/// ERC20/ERC721 standards, such as decimals(), balanceOf(address) and ownerOf(uint256).
///
/// @returns The current read gas limit.
///
access(all)
fun main(): UInt64 {
    return FlowEVMBridgeConfig.readGasLimit()
}
