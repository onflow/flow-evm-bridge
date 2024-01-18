import "EVM"

transaction {
    prepare(signer: auth(LoadValue) &Account) {
        destroy signer.storage.load<@EVM.BridgedAccount>(from: /storage/evm)!
    }
}
