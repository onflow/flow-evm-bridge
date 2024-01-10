import "EVM"

transaction(evmContractAddressHex: String, calldata: String, value: UFix64) {

    prepare(signer: auth(BorrowValue) &Account) {
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
        
        let coa = signer.storage.borrow<&EVM.BridgedAccount>(
                from: /storage/evm
            ) ?? panic("Could not borrow COA from provided gateway address")
        
        coa.call(
            to: evmAddress,
            data: data,
            gasLimit: 100000,
            value: EVM.Balance(flow: value)
        )
    }
}
