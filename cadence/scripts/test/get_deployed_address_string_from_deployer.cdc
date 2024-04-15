import "EVM"

import "EVMDeployer"

import "FlowEVMBridgeUtils"

access(all)
fun main(name: String): String {
    return FlowEVMBridgeUtils.getEVMAddressAsHexString(
        address: EVMDeployer.deployedAddresses[name] ?? panic("Could not find deployed address for: ".concat(name))
    )
}