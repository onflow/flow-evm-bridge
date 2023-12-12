import "EVM"

access(all) fun main(evmAddressString: String): UFix64? {
    return EVM.getBalance(address: evmAddressString)?.flow
}
