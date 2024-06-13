import "EVM"

import "FlowEVMBridgeUtils"

/// Executes an NFT transfer to the defined recipient address against the specified ERC721 contract.
///
transaction(evmContractAddressHex: String, recipientAddressHex: String, id: UInt256) {
    
    let evmContractAddress: EVM.EVMAddress
    let recipientAddress: EVM.EVMAddress
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    var senderOwnerCheck: Bool
    var recipientOwnerCheck: Bool
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.evmContractAddress = EVM.addressFromString(evmContractAddressHex)
        self.recipientAddress = EVM.addressFromString(recipientAddressHex)

        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow CadenceOwnedAccount reference")

        self.senderOwnerCheck = FlowEVMBridgeUtils.isOwnerOrApproved(
                ofNFT: id,
                owner: self.coa.address(),
                evmContractAddress: self.evmContractAddress
            )
        self.recipientOwnerCheck = false
    }

    execute {
        let calldata = EVM.encodeABIWithSignature(
                "safeTransferFrom(address,address,uint256)",
                [self.coa.address(), self.recipientAddress, id]
            )
        let callResult = self.coa.call(
            to: self.evmContractAddress,
            data: calldata,
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(callResult.status == EVM.Status.successful, message: "Call to ERC721 contract failed")
        self.recipientOwnerCheck = FlowEVMBridgeUtils.isOwnerOrApproved(
                ofNFT: id,
                owner: self.recipientAddress,
                evmContractAddress: self.evmContractAddress
            )
    }

    post {
        self.recipientOwnerCheck: "Recipient did not receive the token"
    }
}
