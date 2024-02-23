import "FlowEVMBridgeTemplates"

/// Upserts the provided contract template stored in FlowEVMBridgeTemplates
///
transaction(forTemplate: String, newChunks: [String]) {
    prepare(signer: auth(BorrowValue) &Account) {
        let admin: &FlowEVMBridgeTemplates.Admin = signer.storage.borrow(from: FlowEVMBridgeTemplates.AdminStoragePath)
            ?? panic("Could not borrow FlowEVMBridgeTemplates Admin reference")
        FlowEVMBridgeTemplates.upsertContractCodeChunks(forTemplate: forTemplate, newChunks: newChunks)
    }
}
