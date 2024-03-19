import "EVM"

import "FlowEVMBridgeUtils"

/// Converts EVM address bytes into to a hex string
///
access(all) fun main(bytes: [UInt8]): String? {
    let address = EVM.EVMAddress(
            bytes: [
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4],
                bytes[5], bytes[6], bytes[7], bytes[8], bytes[9],
                bytes[10], bytes[11], bytes[12], bytes[13], bytes[14],
                bytes[15], bytes[16], bytes[17], bytes[18], bytes[19]
            ]
        )
    return FlowEVMBridgeUtils.getEVMAddressAsHexString(address: address)
}
