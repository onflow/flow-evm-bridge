import "EVM"

/// Returns the Flow balance of of a given EVM address in FlowEVM
///
access(all) fun main(address: String): UFix64 {
    let addressBytes = address
        .decodeHex()
        .toConstantSized<[UInt8; 20]>()
        ?? panic("Invalid EVM address")
    return EVM.EVMAddress(bytes: addressBytes).balance().inFLOW()
}
