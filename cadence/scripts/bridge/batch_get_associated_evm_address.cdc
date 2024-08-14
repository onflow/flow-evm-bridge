import "EVM"

import "FlowEVMBridgeConfig"

/// Returns the EVM addresses associated with given Cadence types (as identifier String)
///
/// @param typeIdentifiers: The Cadence type identifier Strings
///
/// @return The EVM addresses as hex strings indexed on the associated Cadence type identifier string if the type has an
///      associated EVMAddress, otherwise nil
access(all)
fun main(identifiers: [String]): {String: String?} {
    let res: {String: String?} = {}
    for identifier in identifiers {
        // skip if already processed
        if res[identifier] != nil {
            continue
        }

        if let type = CompositeType(identifier) {
            if let address = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) {
                res.insert(key: identifier, address.toString())
            }
        }
    }
    return res
}
