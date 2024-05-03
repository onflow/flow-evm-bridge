import "EVM"

import "EVMUtils"

/// Sets the registrar address for the provided FlowBridgeDeploymentRegistry address. Should be called by the owner of
/// the registry contract.
///
/// @param registryEVMAddressHex The EVM address of the FlowBridgeDeploymentRegistry contract.
/// @param registrarEVMAddressHex The EVM address of the registrar contract.
///
transaction(registryEVMAddressHex: String, registrarEVMAddressHex: String) {
    
    let coa: auth(Call) &CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        let registryEVMAddress = EVMUtils.getEVMAddressFromHexString(address: registryEVMAddressHex)
            ?? panic("Could not convert registry address to EVM address")
        let registrarEVMAddress = EVMUtils.getEVMAddressFromHexString(address: registrarEVMAddressHex)
            ?? panic("Could not convert registrar address to EVM address")
        
        self.coa.call(
            to: registryEVMAddress,
            data: EVM.encodeABIWithSignature(
                "setRegistrar(address)",
                [registrarEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
    }
}
