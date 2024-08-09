import "EVM"

/// Transfers FLOW to another EVM address from the signer's COA
transaction(to: String, amount: UInt) {

    let recipient: EVM.EVMAddress
    let recipientPreBalance: UInt
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.recipient = EVM.addressFromString(to)
        self.recipientPreBalance = self.recipient.balance().attoflow
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("No COA found in signer's account")
    }

    execute {
        let res = self.coa.call(
            to: self.recipient,
            data: [],
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: amount)
        )

        assert(res.status == EVM.Status.successful, message: "Failed to transfer FLOW to EVM address")
    }

    post {
        self.recipient.balance().attoflow == self.recipientPreBalance + amount:
            "Problem transferring value to EVM address"
    }
}