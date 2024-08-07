import "EVM"

import "FlowEVMBridgeUtils"

/// This transaction adds the given EVM address as a deployer in the bridge factory contract, indexed on the
/// provided tag.
///
/// @param deployerTag: The tag to index the deployer with - e.g. ERC20, ERC721, etc.
/// @param deployerEVMAddressHex: The EVM address of the deployer contract as a hex string
///
transaction(deployerTag: String, deployerEVMAddressHex: String) {

    let targetDeployerEVMAddress: EVM.EVMAddress
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    var postDeployer: EVM.EVMAddress?

    prepare(signer: auth(BorrowValue) &Account) {
        self.targetDeployerEVMAddress = EVM.addressFromString(deployerEVMAddressHex)
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        self.postDeployer = nil
    }

    execute {
        // Execute the call
        let callResult = self.coa.call(
            to: FlowEVMBridgeUtils.getBridgeFactoryEVMAddress(),
            data: EVM.encodeABIWithSignature(
                "addDeployer(string,address)",
                [deployerTag, self.targetDeployerEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to add deployer")

        // Confirm the deployer was added under the tag
        let postDeployerResult = self.coa.call(
            to: FlowEVMBridgeUtils.getBridgeFactoryEVMAddress(),
            data: EVM.encodeABIWithSignature(
                "getDeployer(string)",
                [deployerTag]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(postDeployerResult.status == EVM.Status.successful, message: "Failed to get deployer")

        let decodedResult = EVM.decodeABI(
                types: [Type<EVM.EVMAddress>()],
                data: postDeployerResult.data
            )
        assert(decodedResult.length == 1, message: "Invalid response from getDeployer call")
        self.postDeployer = decodedResult[0] as! EVM.EVMAddress
    }

    post {
        self.postDeployer!.equals(self.targetDeployerEVMAddress): "Deployer was not properly configured"
    }
}
