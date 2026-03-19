import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

access(all)
fun main(coaHost: Address): String {
    let coa = getAuthAccount<auth(BorrowValue) &Account>(coaHost)
        .storage
        .borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
        ?? panic("Could not borrow CadenceOwnedAccount from host=".concat(coaHost.toString()))
    let res = coa.callWithSigAndArgs(
        to: FlowEVMBridgeUtils.getBridgeFactoryEVMAddress(),
        signature: "getRegistry()",
        args: [],
        gasLimit: FlowEVMBridgeConfig.gasLimit,
        value: EVM.Balance(attoflow: UInt(0)),
        resultTypes: [Type<EVM.EVMAddress>()]
    )

    assert(
        res.status == EVM.Status.successful,
        message: "getRegistry call to FlowEVMBridgeFactory failed"
    )

    assert(res.results.length == 1, message: "Invalid response length")

    return (res.results[0] as! EVM.EVMAddress).toString()
}
