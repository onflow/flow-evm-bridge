import "EVM"

import "EVMUtils"
import "FlowEVMBridgeUtils"

access(all)
fun main(evmAddressHex: String): String {
    return FlowEVMBridgeUtils.deriveBridgedNFTContractName(
        from: EVMUtils.getEVMAddressFromHexString(address: evmAddressHex) ?? panic("Could not parse EVM address from hex string")
    )
}
