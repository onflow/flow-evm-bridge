import "EVM"

/// Returns the Flow balance of of a given EVM address in FlowEVM in 18 decimal precision
///
access(all) fun main(address: String): UInt {
    return EVM.addressFromString(address).balance().attoflow
}
