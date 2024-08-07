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
        let calldata = EVM.encodeABIWithSignature(
            "safeMint(address,uint256,string)",
            [recipientAddress, tokenId, uri]
        )
        let callResult = self.coa.call(
            to: erc721Address,
            data: calldata,
            gasLimit: gasLimit,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "ERC721 mint failed with code: ".concat(callResult.errorCode.toString()))
    }
}
