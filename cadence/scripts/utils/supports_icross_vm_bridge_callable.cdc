import "EVM"

import "FlowEVMBridgeUtils"

/// Returns whether a given EVM contract supports the ICrossVMBridgeCallable.sol contract interface
///
access(all)
fun main(evmContractAddress: String): Bool {
    return FlowEVMBridgeUtils.supportsICrossVMBridgeCallable(
        evmContract: EVM.addressFromString(evmContractAddress)
    )
}
