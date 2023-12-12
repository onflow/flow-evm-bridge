import "EVM"

transaction {

    prepare(signer: AuthAccount) {
        if signer.type(at: EVM.StoragePath) == nil {
            signer.save(<-EVM.createBridgedAccount(), to: EVM.StoragePath)
        }
        if !signer.getCapability<&{EVM.BridgedAccountPublic}>(EVM.PublicPath).check() {
            signer.unlink(EVM.PublicPath)
            signer.link<&{EVM.BridgedAccountPublic}>(EVM.PublicPath, target: EVM.StoragePath)
        }
    }
}
