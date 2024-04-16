import "EVM"

import "EVMUtils"
import "FlowEVMBridgeUtils"

/// Returns the balance of the owner (hex-encoded EVM address - minus 0x prefix) of a given ERC20 fungible token defined
/// at the hex-encoded EVM contract address
///
/// @param owner: The hex-encoded EVM address of the owner without the 0x prefix
/// @param evmContractAddress: The hex-encoded EVM contract address of the ERC20 contract without the 0x prefix
///
/// @return The balance of the address, reverting if the given contract address does not implement the ERC20 method
///     "balanceOf(address)(uint256)"
///
access(all) fun main(owner: String, evmContractAddress: String): UInt256 {
    return FlowEVMBridgeUtils.balanceOf(
        owner: EVMUtils.getEVMAddressFromHexString(address: owner)
            ?? panic("Invalid owner address"),
        evmContractAddress: EVMUtils.getEVMAddressFromHexString(address: evmContractAddress)
            ?? panic("Invalid EVM contract address")
    )
}
