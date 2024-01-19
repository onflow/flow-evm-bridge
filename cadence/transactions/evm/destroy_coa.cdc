import "EVM"

/// !!! CAUTION: Destroys the COA in the signer's account !!! 
///
transaction {
    prepare(signer: auth(LoadValue) &Account) {
        destroy signer.storage.load<@EVM.BridgedAccount>(from: /storage/evm)!
    }
}
