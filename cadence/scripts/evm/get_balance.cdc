import "EVM"

/// Returns the Flow balance of of a given EVM address in FlowEVM
///
access(all) fun main(address: String): UFix64 {
    return EVM.addressFromString(address).balance().inFLOW()
}
