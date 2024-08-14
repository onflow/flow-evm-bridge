import "EVM"

import "FlowEVMBridgeConfig"

/// Returns a mapping of Cadence Type associated with the given EVM addresses (as hex Strings)
///
/// @param evmAddresses: An array hex-encoded addresses of the EVM contract as a Strings
///
/// @return The Cadence Types associated with indexed EVM address or nil if the address is not onboarded. `nil` may
///        also be returned if the address is not a valid EVM address.
///
access(all)
fun main(addressHex: [String]): {String: Type?} {
    let res: {String: Type?} = {}
    for hex in addressHex {
        // skip if already processed
        if res[hex] != nil {
            continue
        }

        let address = EVM.addressFromString(hex)
        let type = FlowEVMBridgeConfig.getTypeAssociated(with: address)

        res.insert(key: hex, type)
    }
    return res
}
