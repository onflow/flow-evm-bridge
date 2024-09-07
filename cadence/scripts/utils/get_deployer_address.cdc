import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

access(all)
fun main(coaHost: Address, deployerTag: String): String {
    let coa = getAuthAccount<auth(BorrowValue) &Account>(coaHost)
        .storage
        .borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
        ?? panic("Could not borrow CadenceOwnedAccount from host=".concat(coaHost.toString()))
    let res = coa.call(
        to: FlowEVMBridgeUtils.getBridgeFactoryEVMAddress(),
        data: EVM.encodeABIWithSignature("getDeployer(string)", [deployerTag]),
        gasLimit: FlowEVMBridgeConfig.gasLimit,
        value: EVM.Balance(attoflow: UInt(0))
    )

    assert(
        res.status == EVM.Status.successful,
        message: "getRegistry call to FlowEVMBridgeFactory failed"
    )

    let decodedRes = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: res.data) 

    assert(decodedRes.length == 1, message: "Invalid response length")

    return (decodedRes[0] as! EVM.EVMAddress).toString()
}
