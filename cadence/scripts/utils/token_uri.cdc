import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the tokenURI of the given tokenID from the given EVM contract address
///
/// @param coaHost: The Flow account Address of the account that hosts the COA used to make the call
/// @param id: The ID of the ERC721 token
/// @param contractAddressHex: The hex string of the contract address (without 0x prefix) of the ERC721 token
///
/// @return The tokenURI of the given tokenID from the given EVM contract address. Reverts if the call is unsuccessful
///
access(all) fun main(contractAddressHex: String, tokenID: UInt256): String? {
    let address = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: contractAddressHex)
        ?? panic("Problem ")
    return FlowEVMBridgeUtils.getTokenURI(
        evmContractAddress: address,
        id: tokenID
    )
}
