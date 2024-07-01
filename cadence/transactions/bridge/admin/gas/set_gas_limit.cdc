import "FlowEVMBridgeConfig"

/// Sets the gas limit for all bridge-related operations in EVM.
///
/// @param gasLimit: The new gas limit for all bridge-related operations in EVM.
///
transaction(gasLimit: UInt64) {

    let admin: auth(FlowEVMBridgeConfig.Gas) &FlowEVMBridgeConfig.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeConfig.Gas) &FlowEVMBridgeConfig.Admin>(from: FlowEVMBridgeConfig.adminStoragePath)
            ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
    }

    execute {
        self.admin.setGasLimit(gasLimit)
    }

    post {
        FlowEVMBridgeConfig.gasLimit == gasLimit: "Problem setting gasLimit to: ".concat(gasLimit.toString())
    }
}
