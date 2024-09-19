import "EVM"

import "FlowEVMBridgeConfig"

/// Blocks the given EVM contract address from onboarding.
///
/// @param evmContractHex: The EVM contract address to block from onboarding
///
transaction(evmContractHex: String) {

    let admin: auth(FlowEVMBridgeConfig.Blocklist) &FlowEVMBridgeConfig.Admin
    let evmAddress: EVM.EVMAddress

    prepare(signer: auth(BorrowValue) &Account) {
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeConfig.Blocklist) &FlowEVMBridgeConfig.Admin>(
                from: FlowEVMBridgeConfig.adminStoragePath
            ) ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
        self.evmAddress = EVM.addressFromString(evmContractHex)
    }

    execute {
        self.admin.blockEVMAddress(self.evmAddress)
    }

    post {
        FlowEVMBridgeConfig.isEVMAddressBlocked(self.evmAddress): "Fee was not set correctly"
    }
}
