import "EVM"

transaction(
    recipientHexAddress: String,
    tokenId: UInt256,
    uri: String,
    erc721HexAddress: String,
    gasLimit: UInt64
) {
    
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Signer does not have a COA in storage")
    }

    execute {
        let recipientAddress = EVM.addressFromString(recipientHexAddress)
        let erc721Address = EVM.addressFromString(erc721HexAddress)
        let callResult = self.coa.callWithSigAndArgs(
            to: erc721Address,
            signature: "safeMint(address,uint256,string)",
            args: [recipientAddress, tokenId, uri],
            gasLimit: gasLimit,
            value: 0,
            resultTypes: nil
        )
        assert(callResult.status == EVM.Status.successful, message: "ERC721 mint failed with code: \(callResult.errorCode.toString())")
    }
}
