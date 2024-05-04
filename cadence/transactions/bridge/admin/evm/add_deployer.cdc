import "EVM"

import "EVMUtils"
import "FlowEVMBridgeUtils"

transaction(deployerTag: String, deployerEVMAddressHex: String) {
    
    let coa: auth(Call) &CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        let deployerEVMAddress = EVMUtils.getEVMAddressFromHexString(address: deployerEVMAddressHex)
            ?? panic("Could not convert deployer contract address to EVM address")
        
        let callResult = self.coa.call(
            to: FlowEVMBridgeUtils.bridgeFactoryEVMAddress,
            data: EVM.encodeABIWithSignature(
                "addDeployer(string, address)",
                [deployerTag, deployerEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.success == EVM.Status.successful, message: "Failed to add deployer")
    }
}
