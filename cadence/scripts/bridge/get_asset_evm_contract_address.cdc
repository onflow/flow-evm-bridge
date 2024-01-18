import "EVM"

import "FlowEVMBridge"
import "FlowEVMBridgeUtils"

access(all) fun main(typeIdentifier: String): String? {
    if let type: Type = CompositeType(typeIdentifier) {
        if let address: EVM.EVMAddress = FlowEVMBridge.getAssetEVMContractAddress(type: type) {
            return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: address)
        }
    }
    return nil
}
