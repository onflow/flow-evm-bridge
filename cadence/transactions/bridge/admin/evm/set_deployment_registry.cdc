import "EVM"

import "FlowEVMBridgeUtils"

/// This transaction sets the address of the registry contract in the bridge factory contract. The registry contract
/// is tasked with maintaining associations between bridge-deployed EVM contracts and their corresponding Cadence
/// implementations.
///
/// NOTE: This is a sensitive operation as the registry contract serves as the source of truth for bridge-deployed
/// contracts.
///
/// @param registryEVMAddressHex The EVM address of the registry contract as a hex string
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
            to: FlowEVMBridgeUtils.bridgeFactoryEVMAddress,
            data: EVM.encodeABIWithSignature(
                "setDeploymentRegistry(address)",
                [registryEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to set delegated deployer")
    }
}
