import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the EVM address of the current owner of the provided ERC721 token
///
/// @param id: The ERC721 ID of the NFT
/// @param evmContractAddress: The hex-encoded EVM contract address of the ERC721 contract
///
/// @return The EVM address hex of the token owner or nil if the `ownerOf` call fails
///
access(all) fun main(id: UInt256, evmContractAddress: String): String? {
    return FlowEVMBridgeUtils.ownerOf(
        id: id,
        evmContractAddress: EVM.addressFromString(evmContractAddress),
    )?.toString()
}
