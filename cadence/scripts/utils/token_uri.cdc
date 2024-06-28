import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the tokenURI of the given tokenID from the given EVM contract address
///
/// @param contractAddressHex: The hex string of the contract address of the ERC721 token
/// @param tokenID: The ID of the ERC721 token
///
/// @return The tokenURI of the given tokenID from the given EVM contract address. Reverts if the call is unsuccessful
///
access(all) fun main(contractAddressHex: String, tokenID: UInt256): String? {
    return FlowEVMBridgeUtils.getTokenURI(
        evmContractAddress: EVM.addressFromString(contractAddressHex),
        id: tokenID
    )
}
