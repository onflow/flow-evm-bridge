import "EVM"

transaction {
    prepare(signer: auth(UnpublishCapability, GetStorageCapabilityController, LoadValue) &Account)  {
        signer.capabilities.unpublish(/public/evm)
        let controllers = signer.capabilities.storage.getControllers(forPath: /storage/evm)
        for con in controllers {
            con.delete()
        }
        destroy signer.storage.load<@EVM.CadenceOwnedAccount>(from: /storage/evm)
    }
}