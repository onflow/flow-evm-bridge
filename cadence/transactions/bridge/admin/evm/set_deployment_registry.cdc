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

    let targetRegistryEVMAddress: EVM.EVMAddress
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    var postRegistry: EVM.EVMAddress?

    prepare(signer: auth(BorrowValue) &Account) {
        self.targetRegistryEVMAddress = EVM.addressFromString(registryEVMAddressHex)
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
            self.postRegistry = nil
    }

    execute {
        // Execute call
        let callResult = self.coa.call(
            to: FlowEVMBridgeUtils.getBridgeFactoryEVMAddress(),
            data: EVM.encodeABIWithSignature(
                "setDeploymentRegistry(address)",
                [self.targetRegistryEVMAddress]
            ),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "Failed to set registry in FlowBridgeFactory contract")

        // Confirm the registry address was set
        let postRegistryResult = self.coa.call(
            to: FlowEVMBridgeUtils.getBridgeFactoryEVMAddress(),
            data: EVM.encodeABIWithSignature("getRegistry()", []),
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(
            postRegistryResult.status == EVM.Status.successful,
            message: "Failed to get registry address from FlowBridgeFactory contract"
        )

        let decodedResult = EVM.decodeABI(
                types: [Type<EVM.EVMAddress>()],
                data: postRegistryResult.data
            )
        assert(decodedResult.length == 1, message: "Invalid response from getRegistry() call to FlowBridgeFactory contract")
        self.postRegistry = decodedResult[0] as! EVM.EVMAddress
    }

    post {
        self.postRegistry!.equals(self.targetRegistryEVMAddress):
            "Registry address "
            .concat(registryEVMAddressHex)
            .concat(" was not set in the FlowBridgeFactory contract ")
            .concat(FlowEVMBridgeUtils.getBridgeFactoryEVMAddress().toString())
    }
}
