import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the tokenURI of the given tokenID from the given EVM contract address
///
access(all) fun main(contractAddressHex: String, tokenID: UInt256): String {
    let address = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: contractAddressHex)
        ?? panic("Problem ")
    return FlowEVMBridgeUtils.getTokenURI(
        evmContractAddress: address,
        id: tokenID
    )
}
