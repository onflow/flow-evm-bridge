import "EVM"

access(all) fun main(gatewayAddress: Address, evmContractAddressHex: String, calldata: String): UInt256 {

    let evmAddressBytes: [UInt8] = evmContractAddressHex.decodeHex()
    let evmAddress = EVM.EVMAddress(
            bytes: [
                evmAddressBytes[0], evmAddressBytes[1], evmAddressBytes[2], evmAddressBytes[3], evmAddressBytes[4],
                evmAddressBytes[5], evmAddressBytes[6], evmAddressBytes[7], evmAddressBytes[8], evmAddressBytes[9],
                evmAddressBytes[10], evmAddressBytes[11], evmAddressBytes[12], evmAddressBytes[13], evmAddressBytes[14],
                evmAddressBytes[15], evmAddressBytes[16], evmAddressBytes[17], evmAddressBytes[18], evmAddressBytes[19]
            ]
        )

    let data: [UInt8] = calldata.decodeHex()

    let gatewayCOA = getAuthAccount<auth(BorrowValue) &Account>(gatewayAddress).storage.borrow<&EVM.BridgedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA from provided gateway address")

    let evmResult = gatewayCOA.call(
        to: evmAddress,
        data: data,
        gasLimit: 30000,
        value: EVM.Balance(flow: 0.0)
    )

    return EVM.decodeABI(types: [Type<UInt256>()], data: evmResult)[0] as! UInt256
}
