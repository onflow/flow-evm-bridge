import "FlowEVMBridgeConfig"

/// Sets the gas limit the bridge declares for read-only EVM calls whose cost is bounded by the
/// ERC20/ERC721 standards.
///
/// @param readGasLimit: The new read gas limit.
///
transaction(readGasLimit: UInt64) {

    let admin: auth(FlowEVMBridgeConfig.Gas) &FlowEVMBridgeConfig.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeConfig.Gas) &FlowEVMBridgeConfig.Admin>(from: FlowEVMBridgeConfig.adminStoragePath)
            ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
    }

    execute {
        self.admin.setReadGasLimit(readGasLimit)
    }

    post {
        FlowEVMBridgeConfig.readGasLimit() == readGasLimit: "Problem setting readGasLimit to: ".concat(readGasLimit.toString())
    }
}
