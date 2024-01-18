import "EVM"

import "FlowEVMBridgeUtils"
import "FlowEVMBridge"

access(all) fun main(): String {
    let address: EVM.EVMAddress = FlowEVMBridge.getBridgeCOAEVMAddress()
    return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: address)
}