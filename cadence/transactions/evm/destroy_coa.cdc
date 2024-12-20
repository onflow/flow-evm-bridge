import "Burner"
import "EVM"

/// !!! CAUTION: Destroys the COA in the signer's account !!!
///
transaction {
    prepare(signer: auth(LoadValue, StorageCapabilities, UnpublishCapability) &Account) {
        // Unpublish the COA capability
        signer.capabilities.unpublish(/public/evm)

        // Delete all COA capabilities
        signer.capabilities.storage.forEachController(forPath: /storage/evm, fun (controller: &StorageCapabilityController): Bool {
            controller.delete()
            return true
        })

        // Destroy the COA
        let coa <- signer.storage.load<@EVM.CadenceOwnedAccount>(from: /storage/evm)!
        Burner.burn(<-coa)
    }
}
