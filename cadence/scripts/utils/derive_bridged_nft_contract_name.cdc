import "EVM"

import "FlowEVMBridgeUtils"

access(all)
fun main(evmAddressHex: String): String {
    return FlowEVMBridgeUtils.deriveBridgedNFTContractName(
        from: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: evmAddressHex) ?? panic("Could not parse EVM address from hex string")
    )
}
