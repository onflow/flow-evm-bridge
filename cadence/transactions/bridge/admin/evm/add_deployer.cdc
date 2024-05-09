import "EVM"

import "EVMUtils"
import "FlowEVMBridgeUtils"

/// This transaction adds the given EVM address as a deployer in the bridge factory contract, indexed on the
/// provided tag.
///
/// @param deployerTag: The tag to index the deployer with - e.g. ERC20, ERC721, etc.
/// @param deployerEVMAddressHex: The EVM address of the deployer contract as a hex string, without the '0x' prefix
///
transaction(deployerTag: String, deployerEVMAddressHex: String) {
    
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
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
                "addDeployer(string,address)",
                [deployerTag, deployerEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to add deployer")
    }
}
