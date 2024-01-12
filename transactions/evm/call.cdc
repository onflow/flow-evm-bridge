import "EVM"

transaction(evmContractAddressHex: String, calldata: String, gasLimit: UInt64, value: UFix64) {

    let evmAddress: EVM.EVMAddress
    let coa: &EVM.BridgedAccount

    prepare(signer: auth(BorrowValue) &Account) {
        let evmAddressBytes: [UInt8] = evmContractAddressHex.decodeHex()
        self.evmAddress = EVM.EVMAddress(
                bytes: [
                    evmAddressBytes[0], evmAddressBytes[1], evmAddressBytes[2], evmAddressBytes[3], evmAddressBytes[4],
                    evmAddressBytes[5], evmAddressBytes[6], evmAddressBytes[7], evmAddressBytes[8], evmAddressBytes[9],
                    evmAddressBytes[10], evmAddressBytes[11], evmAddressBytes[12], evmAddressBytes[13], evmAddressBytes[14],
                    evmAddressBytes[15], evmAddressBytes[16], evmAddressBytes[17], evmAddressBytes[18], evmAddressBytes[19]
                ]
            )
        
        self.coa = signer.storage.borrow<&EVM.BridgedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        self.coa.call(
            to: self.evmAddress,
            data: calldata.decodeHex(),
            gasLimit: gasLimit,
            value: EVM.Balance(flow: value)
        )
    }
}
