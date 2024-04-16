import "EVMUtils"
import "FlowEVMBridgeUtils"

access(all)
fun main(erc20ContractAddressHex: String): UInt8 {
    return FlowEVMBridgeUtils.getTokenDecimals(
        evmContractAddress: EVMUtils.getEVMAddressFromHexString(address: erc20ContractAddressHex)
            ?? panic("Invalid ERC20 address")
    )
}
