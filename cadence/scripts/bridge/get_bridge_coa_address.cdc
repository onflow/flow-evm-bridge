import "EVM"

import "FlowEVMBridgeUtils"
import "FlowEVMBridge"

/// Returns the EVM address associated with the FlowEVMBridge
///
access(all) fun main(): String {
    let address: EVM.EVMAddress = FlowEVMBridge.getBridgeCOAEVMAddress()
    return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: address)
}