import "EVM"

import "EVMUtils"

import "EVMDeployer"

access(all) fun main(): String {
    return EVMUtils.getEVMAddressAsHexString(address: EVMDeployer.deployedContractAddress)
}