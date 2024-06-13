import "EVM"

import "FlowEVMBridgeUtils"

access(all)
fun main(evmAddressHex: String): String {
    return FlowEVMBridgeUtils.deriveBridgedNFTContractName(
        from: EVM.addressFromString(evmAddressHex)
    )
}
