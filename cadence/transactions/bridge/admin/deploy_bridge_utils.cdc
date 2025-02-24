transaction(name: String, code: String, factoryAddress: String) {
  prepare(signer: auth(AddContract) &Account) {
    signer.contracts.add(name: name, code: code.utf8, bridgeFactoryAddressHex: factoryAddress)
  }
}
