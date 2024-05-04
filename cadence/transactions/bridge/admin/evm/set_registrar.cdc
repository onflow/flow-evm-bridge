import "EVM"

import "EVMUtils"
import "FlowEVMBridgeUtils"

/// Sets the registrar address for the provided FlowBridgeDeploymentRegistry address. Should be called by the owner of
/// the registry contract.
///
/// @param registryEVMAddressHex The EVM address of the FlowBridgeDeploymentRegistry contract.
///
transaction(registryEVMAddressHex: String) {
    
    let coa: auth(Call) &CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        let registryEVMAddress = EVMUtils.getEVMAddressFromHexString(address: registryEVMAddressHex)
            ?? panic("Could not convert registry address to EVM address")
        
        let callResult = self.coa.call(
            to: registryEVMAddress,
            data: EVM.encodeABIWithSignature(
                "setRegistrar(address)",
                [FlowEVMBridgeUtils.bridgeFactoryEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.success == EVM.Status.successful, message: "Failed to set delegated deployer")
    }
}
