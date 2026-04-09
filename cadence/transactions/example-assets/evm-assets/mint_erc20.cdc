import "EVM"

transaction(
    recipientHexAddress: String,
    amount: UInt256,
    erc20HexAddress: String,
    gasLimit: UInt64
) {
    
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Signer does not have a COA in storage")
    }

    execute {
        let recipientAddress = EVM.addressFromString(recipientHexAddress)
        let erc20Address = EVM.addressFromString(erc20HexAddress)
        let callResult = self.coa.callWithSigAndArgs(
            to: erc20Address,
            signature: "mint(address,uint256)",
            args: [recipientAddress, amount],
            gasLimit: gasLimit,
            value: 0,
            resultTypes: nil
        )
        assert(callResult.status == EVM.Status.successful, message: "ERC20 mint failed with code: \(callResult.errorCode.toString())")
    }
}
