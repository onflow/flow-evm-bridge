transaction(name: String, code: String, evmAddress: Address) {
  prepare(signer: auth(AddContract) &Account) {
    signer.contracts.add(name: name, code: code.utf8, publishToEVMAccount: evmAddress)
  }
}
