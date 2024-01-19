import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeUtils"

/// Returns the EVM address associated with the given Cadence type
///
access(all) fun main(typeIdentifier: String): String? {
    if let type: Type = CompositeType(typeIdentifier) {
        if let address: EVM.EVMAddress = FlowEVMBridge.getAssetEVMContractAddress(type: type) {
            return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: address)
        }
    }
    return nil
}
