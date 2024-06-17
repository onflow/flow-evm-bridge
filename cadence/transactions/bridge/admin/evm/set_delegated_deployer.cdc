import "EVM"

import "FlowEVMBridgeUtils"

/// Sets the bridge factory contract address as a delegated deployer in the provided deployer contract. This enables the
/// factory contract to deploy new contracts via the deployer contract.
///
/// @param deployerEVMAddressHex The EVM address of the deployer contract as a hex string
///
transaction(deployerEVMAddressHex: String) {
    
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        let deployerEVMAddress = EVM.addressFromString(deployerEVMAddressHex)
        
        let callResult = self.coa.call(
            to: deployerEVMAddress,
            data: EVM.encodeABIWithSignature(
                "setDelegatedDeployer(address)",
                [FlowEVMBridgeUtils.bridgeFactoryEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to set delegated deployer")
    }
}
