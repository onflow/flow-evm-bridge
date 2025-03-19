import "EVM"

import "FlowEVMBridgeUtils"

access(all)
fun main(evmContractAddress: String): Address? {
    return FlowEVMBridgeUtils.getDeclaredCadenceAddressFromCrossVM(
        evmContract: EVM.addressFromString(evmContractAddress)
    )
}
