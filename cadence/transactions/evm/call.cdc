import "EVM"

/// Executes the calldata from the signer's COA
///
transaction(evmContractAddressHex: String, calldata: String, gasLimit: UInt64, value: UFix64) {

    let evmAddress: EVM.EVMAddress
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount

    prepare(signer: auth(BorrowValue) &Account) {
        let evmAddressBytes: [UInt8] = evmContractAddressHex.toLower().decodeHex()
        self.evmAddress = EVM.EVMAddress(
                bytes: [
                    evmAddressBytes[0], evmAddressBytes[1], evmAddressBytes[2], evmAddressBytes[3], evmAddressBytes[4],
                    evmAddressBytes[5], evmAddressBytes[6], evmAddressBytes[7], evmAddressBytes[8], evmAddressBytes[9],
                    evmAddressBytes[10], evmAddressBytes[11], evmAddressBytes[12], evmAddressBytes[13], evmAddressBytes[14],
                    evmAddressBytes[15], evmAddressBytes[16], evmAddressBytes[17], evmAddressBytes[18], evmAddressBytes[19]
                ]
            )
        
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
    }

    execute {
        let valueBalance = EVM.Balance(attoflow: 0)
        valueBalance.setFLOW(flow: value)
        let callResult = self.coa.call(
            to: self.evmAddress,
            data: calldata.decodeHex(),
            gasLimit: gasLimit,
            value: valueBalance
        )
        assert(callResult.status == EVM.Status.successful, message: "Call failed")
    }
}
