import "EVM"

import "EVMUtils"
import "FlowEVMBridgeUtils"

transaction(registryEVMAddressHex: String) {
    
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        let registryEVMAddress = EVMUtils.getEVMAddressFromHexString(address: registryEVMAddressHex)
            ?? panic("Could not convert registry address to EVM address")
        
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
