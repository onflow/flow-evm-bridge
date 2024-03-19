import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// Returns the EVM address associated with the given Cadence type (as its identifier String)
///
/// @param typeIdentifier The Cadence type identifier String
///
/// @return The EVM address as a hex string if the type has an associated EVMAddress, otherwise nil
///
access(all)
fun main(identifier: String): String? {
    if let type = CompositeType(identifier) {
        if let address = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) {
            return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: address)
        }
    }
    return nil
}