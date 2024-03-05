import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the EVM address of the owner of the ERC721 token with the given ID.
access(all) fun main(coaHost: Address, id: UInt256, contractAddressHex: String): EVM.EVMAddress {
    let coa = getAuthAccount<auth(BorrowValue) &Account>(coaHost)
        .storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA from coaHost address")
    let calldata: [UInt8] = FlowEVMBridgeUtils.encodeABIWithSignature("ownerOf(uint256)", [id])
    let response: EVM.Result = coa.call(
            to: FlowEVMBridgeUtils.getEVMAddressFromHexString(address: contractAddressHex)!,
            data: calldata,
            gasLimit: 15000000,
            value: EVM.Balance(attoflow: 0)
        )
    let decodedResponse: [AnyStruct] = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: response.data)
    return decodedResponse[0] as! EVM.EVMAddress
}
