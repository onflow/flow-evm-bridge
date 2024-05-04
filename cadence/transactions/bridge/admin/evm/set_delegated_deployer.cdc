import "EVM"

import "EVMUtils"
import "FlowEVMBridgeUtils"

transaction(deployerEVMAddressHex: String, delegatedEVMAddressHex: String) {
    
    let coa: auth(Call) &CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        let deployerEVMAddress = EVMUtils.getEVMAddressFromHexString(address: deployerEVMAddressHex)
            ?? panic("Could not convert deployer contract address to EVM address")
        
        let callResult = self.coa.call(
            to: deployerEVMAddress,
            data: EVM.encodeABIWithSignature(
                "setDelegatedDeployer(address)",
                [FlowEVMBridgeUtils.bridgeFactoryEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.success == EVM.Status.successful, message: "Failed to set delegated deployer")
    }
}
