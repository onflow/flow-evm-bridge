import "EVM"

import "EVMUtils"
import "FlowEVMBridge"

/// Returns the EVM address associated with the FlowEVMBridge
///
/// @return The EVM address associated with the FlowEVMBridge's coordinating CadenceOwnedAccount
///
access(all) fun main(): String {
    let address: EVM.EVMAddress = FlowEVMBridge.getBridgeCOAEVMAddress()
    return EVMUtils.getEVMAddressAsHexString(address: address)
}