import "EVM"

access(all) contract interface CrossVM {
    access(all) fun evmAddress(): EVM.EVMAddress
}