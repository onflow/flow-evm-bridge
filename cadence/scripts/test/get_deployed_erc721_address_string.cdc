import "EVM"

import "EVMDeployer"

import "FlowEVMBridgeUtils"

access(all)
fun main(): String {
    return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: EVMDeployer.deployedAddress)
}