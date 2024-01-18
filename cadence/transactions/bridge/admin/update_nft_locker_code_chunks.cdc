import "FlowEVMBridgeTemplates"

transaction(newChunks: [String]) {
    prepare(signer: &Account) {
        FlowEVMBridgeTemplates.updateNFTLockerContractCodeChunks(newChunks)
    }
}
