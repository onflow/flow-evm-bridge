import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// Returns the EVM contract address associated with a bridge locker contract
///
access(all) fun main(typeIdentifier: String): String? {

    let type = CompositeType(typeIdentifier) ?? panic("Invalid type identifier")
    if let address = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) {
        return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: address)
    }
    return nil
}
