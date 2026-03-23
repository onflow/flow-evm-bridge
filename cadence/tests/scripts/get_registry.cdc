import "EVM"

import "FlowEVMBridgeUtils"

access(all)
fun main(): String {
    let coa = getAuthAccount<auth(BorrowValue) &Account>(0xdfc20aee650fcbdf)
        .storage
        .borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Problem borrowing COA")
    // Confirm the registry address was set
    let postRegistryResult = coa.callWithSigAndArgs(
        to: FlowEVMBridgeUtils.getBridgeFactoryEVMAddress(),
        signature: "owner()",
        args: [],
        gasLimit: 15_000_000,
        value: 0,
        resultTypes: [Type<EVM.EVMAddress>()]
    )
    assert(
        postRegistryResult.status == EVM.Status.successful,
        message: "Failed to get registry address from FlowBridgeFactory contract"
    )

    assert(postRegistryResult.results.length == 1, message: "Invalid response from getRegistry() call to FlowBridgeFactory contract")
    return (postRegistryResult.results[0] as! EVM.EVMAddress).toString()
}
