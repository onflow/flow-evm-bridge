import "FlowEVMBridgeUtils"

access(all)
fun main(erc20ContractAddressHex: String): UInt8 {
    return FlowEVMBridgeUtils.getTokenDecimals(
        evmContractAddress: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: erc20ContractAddressHex)
            ?? panic("Invalid ERC20 address")
    )
}
