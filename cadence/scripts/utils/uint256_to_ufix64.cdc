import "FlowEVMBridgeUtils"

access(all)
fun main(value: UInt256, decimals: UInt8): UFix64 {
    return FlowEVMBridgeUtils.uint256ToUFix64(value: value, decimals: decimals)
}
