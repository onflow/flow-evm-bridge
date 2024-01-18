import "EVM"

import "FlowEVMBridgeUtils"

access(all) fun main(): String {
    return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: FlowEVMBridgeUtils.bridgeFactoryEVMAddress)
}