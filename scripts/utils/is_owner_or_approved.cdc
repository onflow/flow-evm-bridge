import "EVM"

import "FlowEVMBridgeUtils"

access(all) fun main(ofNFT: UInt256, owner: String, evmContractAddress: String): Bool {
    return FlowEVMBridgeUtils.isOwnerOrApproved(
        ofNFT: ofNFT,
        owner: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: owner)
            ?? panic("Invalid owner address"),
        evmContractAddress: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: evmContractAddress)
            ?? panic("Invalid EVM contract address")
    )
}
