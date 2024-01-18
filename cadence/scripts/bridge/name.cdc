import "EVM"

import "FlowEVMBridgeUtils"

access(all) fun main(coaHost: Address, contractAddressHex: String): String {
    let coa: &EVM.BridgedAccount = getAuthAccount<auth(BorrowValue) &Account>(coaHost).storage.borrow<&EVM.BridgedAccount>(
            from: /storage/evm
        )!
    let calldata: [UInt8] = FlowEVMBridgeUtils.encodeABIWithSignature("name()", [])
    let response: [UInt8] = coa.call(
            to: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: contractAddressHex)!,
            data: calldata,
            gasLimit: 15000000,
            value: EVM.Balance(flow: 0.0)
        )
    let decodedResponse: [AnyStruct] = EVM.decodeABI(types: [Type<String>()], data: response)
    return decodedResponse[0] as! String
}
