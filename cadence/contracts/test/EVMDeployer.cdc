import "EVM"

/// NOTE: NOT INTENDED FOR PRODUCTION USE - USED FOR TEMPORARY TESTING PURPOSES ONLY
///
/// This contract is intended for testing purposes for the sake of capturing a deployed contract addresses while native
/// `evm.TransactionExecuted` event types are not available in Cadence testing framework. The deploying account should
/// already be configured with a `CadenceOwnedAccount` resource in storage at `/storage/evm`.
///
access(all) contract EVMDeployer {

    access(all) let deployedAddresses: {String: EVM.EVMAddress}

    access(all) fun deploy(name: String, bytecode: String, value: UInt) {
        pre {
            self.deployedAddresses[name] == nil: "Already deployed contract under provided"
        }
        post {
            self.deployedAddresses[name] != nil : "Deployment address was not stored"
        }
        let deploymentAddress = self.borrowCOA().deploy(
            code: bytecode.decodeHex(),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: value)
        )
        self.deployedAddresses[name] = deploymentAddress
    }

    access(self) fun borrowCOA(): auth(EVM.Deploy) &EVM.CadenceOwnedAccount {
        return self.account.storage.borrow<auth(EVM.Deploy) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("No COA found in storage")
    }

    init() {
        self.deployedAddresses = {}
    }
}
