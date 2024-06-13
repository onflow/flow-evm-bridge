import "EVM"

import "FlowEVMBridgeUtils"

/// Sets the bridge factory contract address as the registrar for the provided FlowBridgeDeploymentRegistry address.
/// Should be called by the owner of the registry contract.
///
/// @param registryEVMAddressHex The EVM address of the FlowBridgeDeploymentRegistry contract.
///
transaction(registryEVMAddressHex: String) {
    
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
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
    }
}
