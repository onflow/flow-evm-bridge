import "EVM"

import "FlowEVMBridge"

/// Returns the EVM address associated with the FlowEVMBridge
///
/// @return The EVM address associated with the FlowEVMBridge's coordinating CadenceOwnedAccount
///
access(all) fun main(): String {
    return FlowEVMBridge.getBridgeCOAEVMAddress().toString()
}