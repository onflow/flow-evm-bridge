import "EVM"

/// Contract interface denoting a cross-VM implementation, exposing methods to query EVM-associated addresses
access(all) contract interface ICrossVM {
    /// Retrieves the corresponding EVM contract address, assuming a 1:1 relationship between VM implementations
    // TODO: Make view once EVMAddress.address() is view
    access(all) fun getEVMContractAddress(): EVM.EVMAddress
}