import "EVM"

import "FlowEVMBridgeUtils"

access(all)
fun main(evmAddressHex: String): String {
    return FlowEVMBridgeUtils.deriveBridgedTokenContractName(
        from: EVM.addressFromString(evmAddressHex)
    )
}
