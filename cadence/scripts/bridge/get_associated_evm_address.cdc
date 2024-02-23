import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

access(all)
fun main(identifier: String): String? {
    if let type = CompositeType(identifier) {
        if let address = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) {
            return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: address)
        }
    }
    return nil
}