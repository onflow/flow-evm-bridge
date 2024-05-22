import "EVM"

import "EVMUtils"
import "FlowEVMBridgeConfig"

/// Returns the Cadence Type associated with the given EVM address (as its hex String)
///
/// @param evmAddressHex: The hex-encoded address of the EVM contract as a String
///
/// @return The Cadence Type associated with the EVM address or nil if the address is not onboarded. `nil` may also be
///        returned if the address is not a valid EVM address.
///
access(all)
fun main(addressHex: String): Type? {
    let address = EVMUtils.getEVMAddressFromHexString(address: addressHex)
    return address != nil ? FlowEVMBridgeConfig.getTypeAssociated(with: address!) : nil
}
