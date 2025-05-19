import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the declared vmBridgeAddress from a ICrossVMBridgeCallable.sol conforming contract or nil if the contract
/// does not conform to the interface.
///
access(all)
fun main(evmContractAddress: String): EVM.EVMAddress? {
    return FlowEVMBridgeUtils.getVMBridgeAddressFromICrossVMBridgeCallable(
        evmContract: EVM.addressFromString(evmContractAddress)
    )
}
