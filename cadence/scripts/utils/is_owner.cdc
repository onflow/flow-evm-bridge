import "EVM"

import "EVMUtils"
import "FlowEVMBridgeUtils"

/// Returns whether the given owner (hex-encoded EVM address - minus 0x prefix) is the owner of the given ERC721 NFT
/// defined at the hex-encoded EVM contract address
///
/// @param ofNFT: The ERC721 ID of the NFT
/// @param owner: The hex-encoded EVM address of the owner without the 0x prefix
/// @param evmContractAddress: The hex-encoded EVM contract address of the ERC721 contract without the 0x prefix
///
/// @return Whether the given owner is the owner of the given ERC721 NFT. Reverts on call failure.
///
access(all) fun main(ofNFT: UInt256, owner: String, evmContractAddress: String): Bool {
    return FlowEVMBridgeUtils.isOwner(
        ofNFT: ofNFT,
        owner: EVMUtils.getEVMAddressFromHexString(address: owner)
            ?? panic("Invalid owner address"),
        evmContractAddress: EVMUtils.getEVMAddressFromHexString(address: evmContractAddress)
            ?? panic("Invalid EVM contract address")
    )
}
