transaction(name: String, bytecode: [UInt8]) {
    prepare(signer: auth(UpdateContract) &Account) {
        signer.contracts.update(name: name, code: bytecode)
    }
}