import "EVM"
import "FlowEVMBridgeUtils"

/// Returns whether the given ERC721 exists, assuming the contract implements `exists(uint256)(bool)` otherwise reverts
///
/// @param erc721Address: The EVM contract address of the ERC721 token
/// @param id: The ID of the ERC721 token to check
///
/// @return true if the ERC721 token exists, false otherwise
///
access(all)
fun main(erc721Address: String, id: UInt256): Bool {
    return FlowEVMBridgeUtils.erc721Exists(
        erc721Address: EVM.addressFromString(erc721Address),
        id: id
    )
}
