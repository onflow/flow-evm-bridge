import "EVM"

import "FlowEVMBridgeUtils"

/// Returns whether the given owner (hex-encoded EVM address) is the owner or approved of the given
/// ERC721 NFT defined at the hex-encoded EVM contract address
///
/// @param ofNFT: The ERC721 ID of the NFT
/// @param owner: The hex-encoded EVM address of the owner
/// @param evmContractAddress: The hex-encoded EVM contract address of the ERC721 contract
///
/// @return Whether the given owner is the owner or approved of the given ERC721 NFT. Reverts on call failure.
///
access(all) fun main(ofNFT: UInt256, owner: String, evmContractAddress: String): Bool {
    return FlowEVMBridgeUtils.isOwnerOrApproved(
        ofNFT: ofNFT,
        owner: EVM.addressFromString(owner),
        evmContractAddress: EVM.addressFromString(evmContractAddress)
    )
}
