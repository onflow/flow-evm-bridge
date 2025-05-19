import "EVM"

import "FlowEVMBridgeUtils"

access(all)
fun main(evmContractAddress: String): Type? {
    return FlowEVMBridgeUtils.getDeclaredCadenceTypeFromCrossVM(
        evmContract: EVM.addressFromString(evmContractAddress)
    )
}
