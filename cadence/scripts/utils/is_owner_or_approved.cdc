import "EVM"

import "FlowEVMBridgeUtils"

/// Returns whether the given owner (hex-encoded EVM address - minus 0x prefix) is the owner or approved of the given
/// ERC721 NFT defined at the hex-encoded EVM contract address
///
access(all) fun main(ofNFT: UInt256, owner: String, evmContractAddress: String): Bool {
    return FlowEVMBridgeUtils.isOwnerOrApproved(
        ofNFT: ofNFT,
        owner: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: owner)
            ?? panic("Invalid owner address"),
        evmContractAddress: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: evmContractAddress)
            ?? panic("Invalid EVM contract address")
    )
}
