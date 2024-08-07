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
        let callResult = self.coa.call(
            to: self.targetDeployerEVMAddress,
            data: EVM.encodeABIWithSignature(
                "setDelegatedDeployer(address)",
                [FlowEVMBridgeUtils.getBridgeFactoryEVMAddress()]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to set delegated deployer")

        // Confirm the delegated deployer was set
        let postDelegatedDeployerResult = self.coa.call(
            to: self.targetDeployerEVMAddress,
            data: EVM.encodeABIWithSignature("delegatedDeployer()", []),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(postDelegatedDeployerResult.status == EVM.Status.successful, message: "Failed to get delegated deployer")

        let decodedResult = EVM.decodeABI(
                types: [Type<EVM.EVMAddress>()],
                data: postDelegatedDeployerResult.data
            ) as! [AnyStruct]
        assert(decodedResult.length == 1, message: "Invalid response from delegatedDeployer() call")
        self.postDelegatedDeployer = decodedResult[0] as! EVM.EVMAddress
    }

    post {
        self.postDelegatedDeployer!.equals(FlowEVMBridgeUtils.getBridgeFactoryEVMAddress()):
            "FlowBridgeFactory address "
            .concat(FlowEVMBridgeUtils.getBridgeFactoryEVMAddress().toString())
            .concat(" was not set as the delegated deployer in the deployer contract ")
            .concat(deployerEVMAddressHex)
    }
}
