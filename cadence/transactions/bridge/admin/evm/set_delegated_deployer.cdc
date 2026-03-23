import "EVM"

import "FlowEVMBridgeUtils"

/// Sets the bridge factory contract address as a delegated deployer in the provided deployer contract. This enables the
/// factory contract to deploy new contracts via the deployer contract.
///
/// @param deployerEVMAddressHex The EVM address of the deployer contract as a hex string
///
transaction(deployerEVMAddressHex: String) {

    let targetDeployerEVMAddress: EVM.EVMAddress
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    var postDelegatedDeployer: EVM.EVMAddress?

    prepare(signer: auth(BorrowValue) &Account) {
        self.targetDeployerEVMAddress = EVM.addressFromString(deployerEVMAddressHex)
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        self.postDelegatedDeployer = nil
    }

    execute {
        // Execute the call
        let callResult = self.coa.callWithSigAndArgs(
            to: self.targetDeployerEVMAddress,
            signature: "setDelegatedDeployer(address)",
            args: [FlowEVMBridgeUtils.getBridgeFactoryEVMAddress()],
            gasLimit: 15_000_000,
            value: 0,
            resultTypes: nil
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to set delegated deployer")

        // Confirm the delegated deployer was set
        let postDelegatedDeployerResult = self.coa.callWithSigAndArgs(
            to: self.targetDeployerEVMAddress,
            signature: "delegatedDeployer()",
            args: [],
            gasLimit: 15_000_000,
            value: 0,
            resultTypes: [Type<EVM.EVMAddress>()]
        )
        assert(postDelegatedDeployerResult.status == EVM.Status.successful, message: "Failed to get delegated deployer")

        assert(postDelegatedDeployerResult.results.length == 1, message: "Invalid response from delegatedDeployer() call")
        self.postDelegatedDeployer = postDelegatedDeployerResult.results[0] as! EVM.EVMAddress
    }

    post {
        self.postDelegatedDeployer!.equals(FlowEVMBridgeUtils.getBridgeFactoryEVMAddress()):
            "FlowBridgeFactory address "
            .concat(FlowEVMBridgeUtils.getBridgeFactoryEVMAddress().toString())
            .concat(" was not set as the delegated deployer in the deployer contract ")
            .concat(deployerEVMAddressHex)
    }
}
