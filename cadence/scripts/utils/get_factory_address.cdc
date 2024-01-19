import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the EVM address of the FlowEVMBridge Factory solidity contract
///
access(all) fun main(): String {
    return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: FlowEVMBridgeUtils.bridgeFactoryEVMAddress)
}