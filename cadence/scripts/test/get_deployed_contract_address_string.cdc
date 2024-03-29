import "EVM"

import "FlowEVMBridgeUtils"

import "EVMDeployer"

access(all) fun main(): String {
    return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: EVMDeployer.deployedContractAddress)
}