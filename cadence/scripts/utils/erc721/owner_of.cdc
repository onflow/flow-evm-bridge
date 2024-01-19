import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the EVM address of the owner of the ERC721 token with the given ID.
access(all) fun main(coaHost: Address, id: UInt256, contractAddressHex: String): EVM.EVMAddress {
    let coa: &EVM.BridgedAccount = getAuthAccount<auth(BorrowValue) &Account>(coaHost).storage.borrow<&EVM.BridgedAccount>(
            from: /storage/evm
        )!
    let calldata: [UInt8] = FlowEVMBridgeUtils.encodeABIWithSignature("ownerOf(uint256)", [id])
    let response: [UInt8] = coa.call(
            to: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: contractAddressHex)!,
            data: calldata,
            gasLimit: 15000000,
            value: EVM.Balance(flow: 0.0)
        )
    let decodedResponse: [AnyStruct] = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: response)
    return decodedResponse[0] as! EVM.EVMAddress
}
