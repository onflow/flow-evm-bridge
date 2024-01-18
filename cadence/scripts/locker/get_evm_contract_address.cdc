import "EVM"

import "IEVMBridgeNFTLocker"
import "FlowEVMBridgeUtils"
import "FlowEVMBridge"

/// Returns the EVM contract address associated with a bridge locker contract
///
access(all) fun main(typeIdentifier: String): String? {

    let type = CompositeType(typeIdentifier) ?? panic("Invalid type identifier")
    if let lockerContract: &IEVMBridgeNFTLocker = FlowEVMBridge.borrowLockerContract(forType: type) {
        return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: lockerContract.getEVMContractAddress())
    }
    return nil
}
