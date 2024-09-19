import "EVM"

import "FlowEVMBridgeConfig"

/// Unblocks the given EVM contract address from onboarding to the bridge.
///
/// @param evmContractHex: The EVM contract address to unblock
///
transaction(evmContractHex: String) {

    let evmBlocklist: auth(FlowEVMBridgeConfig.Blocklist) &FlowEVMBridgeConfig.EVMBlocklist
    let evmAddress: EVM.EVMAddress

    prepare(signer: auth(BorrowValue) &Account) {
        self.evmBlocklist = signer.storage.borrow<auth(FlowEVMBridgeConfig.Blocklist) &FlowEVMBridgeConfig.EVMBlocklist>(
                from: /storage/evmBlocklist
            ) ?? panic("Could not borrow FlowEVMBridgeConfig EVMBlocklist reference")
        self.evmAddress = EVM.addressFromString(evmContractHex)
    }

    execute {
        self.evmBlocklist.unblock(self.evmAddress)
    }

    post {
        !FlowEVMBridgeConfig.isEVMAddressBlocked(self.evmAddress): "EVM address was not unblocked"
    }
}
