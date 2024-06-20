import "EVM"

import "EVMUtils"
import "FlowEVMBridgeUtils"

/// Sets the bridge factory contract address as a delegated deployer in the provided deployer contract. This enables the
/// factory contract to deploy new contracts via the deployer contract.
///
/// @param deployerEVMAddressHex The EVM address of the deployer contract as a hex string without the '0x' prefix
///
transaction(deployerEVMAddressHex: String) {

    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    var postDelegatedDeployer: EVM.EVMAddress?

    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")

        self.postDelegatedDeployer = nil
    }

    execute {
        // Execute the call
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

        // Confirm the delegated deployer was set
        let postDelegatedDeployerResult = self.coa.call(
            to: deployerEVMAddress,
            data: EVM.encodeABIWithSignature("delegatedDeployer()", []),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(postDelegatedDeployerResult.status == EVM.Status.successful, message: "Failed to get delegated deployer")

        let decodedResult = EVM.decodeABI(
                types: [Type<EVM.EVMAddress>()],
                data: postDelegatedDeployerResult.data
            ) as! [AnyStruct]
        assert(decodedResult.length == 1, message: "Invalid response from delegatedDeployer() call")
        self.postDelegatedDeployer = decodedResult[0] as! EVM.EVMAddress
    }

    post {
        self.postDelegatedDeployer!.toString() == FlowEVMBridgeUtils.bridgeFactoryEVMAddress.toString():
            "FlowBridgeFactory address "
            .concat(FlowEVMBridgeUtils.bridgeFactoryEVMAddress.toString())
            .concat(" was not set as the delegated deployer in the deployer contract ")
            .concat(deployerEVMAddressHex)
    }
}
