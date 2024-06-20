import "EVM"

import "FlowEVMBridgeUtils"

/// Sets the bridge factory contract address as the registrar for the provided FlowBridgeDeploymentRegistry address.
/// Should be called by the owner of the registry contract.
///
/// @param registryEVMAddressHex The EVM address of the FlowBridgeDeploymentRegistry contract.
///
transaction(registryEVMAddressHex: String) {

    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    var postRegistrar: EVM.EVMAddress?

    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        self.postRegistrar = nil
    }

    execute {
        let registryEVMAddress = EVM.addressFromString(registryEVMAddressHex)

        let callResult = self.coa.call(
            to: registryEVMAddress,
            data: EVM.encodeABIWithSignature(
                "setRegistrar(address)",
                [FlowEVMBridgeUtils.bridgeFactoryEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to set registrar")

        // Confirm the registrar was set
        let postRegistrarResult = self.coa.call(
            to: registryEVMAddress,
            data: EVM.encodeABIWithSignature("registrar()", []),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(postRegistrarResult.status == EVM.Status.successful, message: "Failed to get registrar")

        let decodedResult = EVM.decodeABI(
                types: [Type<EVM.EVMAddress>()],
                data: postRegistrarResult.data
            ) as! [AnyStruct]
        assert(decodedResult.length == 1, message: "Invalid response from registrar() call to registry contract")
        self.postRegistrar = decodedResult[0] as! EVM.EVMAddress
    }

    post {
        self.postRegistrar!.toString() == FlowEVMBridgeUtils.bridgeFactoryEVMAddress.toString():
            "FlowBridgeFactory address "
            .concat(FlowEVMBridgeUtils.bridgeFactoryEVMAddress.toString())
            .concat(" was not set as the registrar in the registry contract ")
            .concat(registryEVMAddressHex)
    }
}
