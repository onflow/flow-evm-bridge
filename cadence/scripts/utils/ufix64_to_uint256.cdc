import "FlowEVMBridgeUtils"

access(all)
fun main(value: UFix64, decimals: UInt8): UInt256 {
    return FlowEVMBridgeUtils.ufix64ToUInt256(value: value, decimals: decimals)
}
