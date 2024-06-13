import "EVM"

import "FlowEVMBridgeUtils"

/// This transaction adds the given EVM address as a deployer in the bridge factory contract, indexed on the
/// provided tag.
///
/// @param deployerTag: The tag to index the deployer with - e.g. ERC20, ERC721, etc.
/// @param deployerEVMAddressHex: The EVM address of the deployer contract as a hex string
///
transaction(deployerTag: String, deployerEVMAddressHex: String) {
    
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        let deployerEVMAddress = EVM.addressFromString(deployerEVMAddressHex)
        
        let callResult = self.coa.call(
            to: FlowEVMBridgeUtils.bridgeFactoryEVMAddress,
            data: EVM.encodeABIWithSignature(
                "addDeployer(string,address)",
                [deployerTag, deployerEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to add deployer")
    }
}
