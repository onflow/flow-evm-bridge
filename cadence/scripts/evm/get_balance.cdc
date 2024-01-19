import "EVM"

/// Returns the Flow balance of of a given EVM address in FlowEVM
///
access(all) fun main(address: String): UFix64 {
    let bytes = address.decodeHex()
    let addressBytes: [UInt8; 20] = [
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4],
        bytes[5], bytes[6], bytes[7], bytes[8], bytes[9],
        bytes[10], bytes[11], bytes[12], bytes[13], bytes[14],
        bytes[15], bytes[16], bytes[17], bytes[18], bytes[19]
    ]
    return EVM.EVMAddress(bytes: addressBytes).balance().flow
}
