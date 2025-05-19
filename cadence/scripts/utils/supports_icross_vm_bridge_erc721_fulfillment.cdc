import "EVM"

import "FlowEVMBridgeUtils"

/// Returns whether a given EVM contract supports the ICrossVMBridgeERC721Fulfillment.sol contract interface
///
access(all)
fun main(evmContractAddress: String): Bool {
    return FlowEVMBridgeUtils.supportsICrossVMBridgeERC721Fulfillment(
        evmContract: EVM.addressFromString(evmContractAddress)
    )
}
