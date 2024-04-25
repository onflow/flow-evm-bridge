import "EVM"

import "EVMDeployer"

import "EVMUtils"

access(all)
fun main(name: String): String {
    return EVMUtils.getEVMAddressAsHexString(
        address: EVMDeployer.deployedAddresses[name] ?? panic("Could not find deployed address for: ".concat(name))
    )
}