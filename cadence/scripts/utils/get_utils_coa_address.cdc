import "EVM"

import "FlowEVMBridgeUtils"

access(all) fun main(): String {
    let address: EVM.EVMAddress = FlowEVMBridgeUtils.getInspectorCOAAddress()
    return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: address)
}