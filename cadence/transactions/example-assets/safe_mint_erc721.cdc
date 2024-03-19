import "EVM"

import "FlowEVMBridgeUtils"

transaction(
    recipientHexAddress: String,
    tokenId: UInt64,
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
        let recipientAddress = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: recipientHexAddress)
            ?? panic("Invalid recipient address")
        let erc721Address = FlowEVMBridgeUtils.getEVMAddressFromHexString(address: erc721HexAddress)
            ?? panic("Invalid ERC721 address")
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
        assert(callResult.status == EVM.Status.successful, message: "ERC721 mint failed")
    }
}