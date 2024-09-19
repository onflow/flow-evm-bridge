import "EVM"

import "FlowEVMBridgeConfig"

/// Blocks the given EVM contract address from onboarding.
///
/// @param evmContractHex: The EVM contract address to block from onboarding
///
transaction(evmContractHex: String) {

    let evmBlocklist: auth(FlowEVMBridgeConfig.Blocklist) &FlowEVMBridgeConfig.EVMBlocklist
    let evmAddress: EVM.EVMAddress

    prepare(signer: auth(BorrowValue) &Account) {
        FlowEVMBridgeConfig.initBlocklist()
        self.evmBlocklist = signer.storage.borrow<auth(FlowEVMBridgeConfig.Blocklist) &FlowEVMBridgeConfig.EVMBlocklist>(
                from: FlowEVMBridgeConfig.adminStoragePath
            ) ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
        self.evmAddress = EVM.addressFromString(evmContractHex)
    }

    execute {
        self.evmBlocklist.block(self.evmAddress)
    }

    post {
        FlowEVMBridgeConfig.isEVMAddressBlocked(self.evmAddress): "Fee was not set correctly"
    }
}
