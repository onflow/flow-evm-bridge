import "EVM"

import "FlowEVMBridgeUtils"

/// Sets the bridge factory contract address as the registrar for the provided FlowBridgeDeploymentRegistry address.
/// Should be called by the owner of the registry contract.
///
/// @param registryEVMAddressHex The EVM address of the FlowBridgeDeploymentRegistry contract.
///
transaction(registryEVMAddressHex: String) {

    let targetRegistryEVMAddress: EVM.EVMAddress
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    var postRegistrar: EVM.EVMAddress?

    prepare(signer: auth(BorrowValue) &Account) {
        self.targetRegistryEVMAddress = EVM.addressFromString(registryEVMAddressHex)
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        self.postRegistrar = nil
    }

    execute {
        let callResult = self.coa.callWithSigAndArgs(
            to: self.targetRegistryEVMAddress,
            signature: "setRegistrar(address)",
            args: [FlowEVMBridgeUtils.getBridgeFactoryEVMAddress()],
            gasLimit: 15_000_000,
            value: 0,
            resultTypes: nil
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to set registrar")

        // Confirm the registrar was set
        let postRegistrarResult = self.coa.callWithSigAndArgs(
            to: self.targetRegistryEVMAddress,
            signature: "registrar()",
            args: [],
            gasLimit: 15_000_000,
            value: 0,
            resultTypes: [Type<EVM.EVMAddress>()]
        )
        assert(postRegistrarResult.status == EVM.Status.successful, message: "Failed to get registrar")

        assert(postRegistrarResult.results.length == 1, message: "Invalid response from registrar() call to registry contract")
        self.postRegistrar = postRegistrarResult.results[0] as! EVM.EVMAddress
    }

    post {
        self.postRegistrar!.equals(FlowEVMBridgeUtils.getBridgeFactoryEVMAddress()):
            "FlowBridgeFactory address "
            .concat(FlowEVMBridgeUtils.getBridgeFactoryEVMAddress().toString())
            .concat(" was not set as the registrar in the registry contract ")
            .concat(registryEVMAddressHex)
    }
}
