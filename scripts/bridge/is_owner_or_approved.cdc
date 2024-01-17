import "EVM"

import "FlowEVMBridgeUtils"

access(all) fun main(id: UInt256, evmAddressHex: String, contractAddressHex: String): Bool {
    let evmAddress = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: evmAddressHex)
        ?? panic("Invalid EVM address")
    let contractAddress = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: contractAddressHex)
        ?? panic("Invalid EVM contract address")
    return FlowEVMBridgeUtils.isOwnerOrApproved(ofNFT: id, owner: evmAddress, evmContractAddress: contractAddress)
}
