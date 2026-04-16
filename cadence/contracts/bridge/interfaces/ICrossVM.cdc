import EVM from 0xe467b9dd11fa00df

/// Contract interface denoting a cross-VM implementation, exposing methods to query EVM-associated addresses
///
access(all)
contract interface ICrossVM {

    /// Retrieves the corresponding EVM contract address, assuming a 1:1 relationship between VM implementations
    ///
    access(all)
    view fun getEVMContractAddress(): EVM.EVMAddress
}
