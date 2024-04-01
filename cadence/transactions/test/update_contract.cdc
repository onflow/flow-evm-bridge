transaction(name: String, codeHex: String) {
    prepare(signer: auth(UpdateContract) &Account) {
        signer.contracts.update(name: name, code: codeHex.decodeHex())
    }
}