import "EVM"

/// This contract utilized for test purposes only for the sake of capturing the deployment address
/// of a contract for which one would otherwise have to inspect the event emitting on deployment.
/// Assumes a COA is already configured with sufficient balance to deploy the contract.
///
access(all) contract EVMDeployer {

    access(all) let deployedContractAddress: EVM.EVMAddress

    init(bytecode: String, valueAmount: UFix64) {
        let coa = self.account.storage.borrow<auth(EVM.Deploy) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from deployment account storage")

        let value = EVM.Balance(attoflow: 0)
        value.setFLOW(flow: valueAmount)
        self.deployedContractAddress = coa.deploy(
            code: bytecode.decodeHex(),
            gasLimit: 12_000_000,
            value: value
        )
    }
}
