import "FlowToken"

transaction {
    prepare(signer: auth(Storage) &Account) {
        let v <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())

        signer.storage.save(<-v, to: /storage/temp)

        let loaded <- signer.storage.load<@AnyResource>(from: /storage/temp)
            ?? panic("no resource found in vault storage path")
        
        destroy loaded
    }
}