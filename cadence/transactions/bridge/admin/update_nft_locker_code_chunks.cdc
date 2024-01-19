import "FlowEVMBridgeTemplates"

/// Updates the code chunks of the NFT Locker contract template stored in FlowEVMBridgeTemplates
///
transaction(newChunks: [String]) {
    prepare(signer: &Account) {
        FlowEVMBridgeTemplates.updateNFTLockerContractCodeChunks(newChunks)
    }
}
