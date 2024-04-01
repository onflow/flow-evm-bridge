import "EVM"

/// This contract is intended for testing purposes for the sake of capturing a deployed contract address while native
/// `evm.TransactionExecuted` event types are not available in Cadence testing framework. The deploying account should
/// already be configured with a `CadenceOwnedAccount` resource in storage at `/storage/evm`.
///
access(all) contract EVMDeployer {

    access(all) let deployedAddress: EVM.EVMAddress

    init(bytecode: String, value: UInt) {
        let coa = self.account.storage.borrow<auth(EVM.Deploy) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("No COA found in storage")
        self.deployedAddress = coa.deploy(
            code: bytecode.decodeHex(),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: value)
        )
    }
}
