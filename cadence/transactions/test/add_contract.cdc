transaction(name: String, codeHex: String, arg0: AnyStruct, arg1: AnyStruct) {
    prepare(signer: auth(AddContract) &Account) {
        signer.contracts.add(name: name, code: codeHex.decodeHex(), arg0, arg1)
    }
}