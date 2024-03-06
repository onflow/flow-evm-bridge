import "FlowEVMBridgeTemplates"

/// Upserts the provided contract template stored in FlowEVMBridgeTemplates
///
transaction(forTemplate: String, newChunks: [String]) {
    prepare(signer: auth(BorrowValue) &Account) {
        signer.storage.borrow<&FlowEVMBridgeTemplates.Admin>(from: FlowEVMBridgeTemplates.AdminStoragePath)
            ?.upsertContractCodeChunks(forTemplate: forTemplate, chunks: newChunks)
            ?? panic("Could not borrow FlowEVMBridgeTemplates Admin reference")
    }
}
