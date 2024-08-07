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
    let postRegistryResult = coa.call(
        to: FlowEVMBridgeUtils.getBridgeFactoryEVMAddress(),
        data: EVM.encodeABIWithSignature("owner()", []),
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
    return (decodedResult[0] as! EVM.EVMAddress).toString()
}