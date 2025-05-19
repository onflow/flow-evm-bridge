import "EVM"

transaction(erc721AddressHex: String) {
    prepare(signer: auth(SaveValue) &Account) {
        let erc721Address = EVM.addressFromString(erc721AddressHex)
        signer.storage.save(erc721Address, to: /storage/erc721ContractAddress)
    }
}