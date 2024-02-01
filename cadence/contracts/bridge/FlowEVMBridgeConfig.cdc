/// This contract is used to store configuration information shared by FlowEVMBridge contracts
///
access(all) contract FlowEVMBridgeConfig {

    /// Amount of $FLOW paid to bridge
    access(all) var fee: UFix64
    /// StoragePath where bridge Cadence Owned Account is stored
    access(all) let coaStoragePath: StoragePath
    access(all) let adminStoragePath: StoragePath

    access(all) event BridgeFeeUpdated(old: UFix64, new: UFix64)

    access(all) resource Admin {
        access(all) fun updateFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.fee, new: new)

            FlowEVMBridgeConfig.fee = new
        }
    }

    init() {
        self.fee = 0.0
        self.adminStoragePath = /storage/flowEVMBridgeConfigAdmin
        self.coaStoragePath = /storage/evm

        self.account.storage.save(<-create Admin(), to: self.adminStoragePath)
    }
}
