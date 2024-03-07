import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the name of the ERC721 at the given address.
///
access(all) fun main(coaHost: Address, contractAddressHex: String): String {
    let coa = getAuthAccount<auth(BorrowValue) &Account>(coaHost)
        .storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        )!
    let calldata: [UInt8] = EVM.encodeABIWithSignature("name()", [])
    let response: [UInt8] = coa.call(
            to: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: contractAddressHex)!,
            data: calldata,
            gasLimit: 15000000,
            value: EVM.Balance(attoflow: 0)
        ).data
    let decodedResponse: [AnyStruct] = EVM.decodeABI(types: [Type<String>()], data: response)
    return decodedResponse[0] as! String
}
