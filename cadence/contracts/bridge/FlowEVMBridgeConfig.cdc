/// This contract is used to store configuration information shared by FlowEVMBridge contracts
///
access(all) contract FlowEVMBridgeConfig {

    /// Amount of FLOW paid to onboard a Type or EVMAddress to the bridge
    access(all) var onboardFee: UFix64
    /// Amount of FLOW paid to bridge
    access(all) var bridgeFee: UFix64
    /// StoragePath where bridge Cadence Owned Account is stored
    access(all) let coaStoragePath: StoragePath
    access(all) let adminStoragePath: StoragePath
    access(all) let bridgeAccessorPublicPath: PublicPath

    access(all) event BridgeFeeUpdated(old: UFix64, new: UFix64, isOnboarding: Bool)

    access(all) resource Admin {
        access(all) fun updateOnboardingFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.onboardFee, new: new, isOnboarding: true)
            FlowEVMBridgeConfig.onboardFee = new
        }
        access(all) fun updateBridgeFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.bridgeFee, new: new, isOnboarding: false)
            FlowEVMBridgeConfig.bridgeFee = new
        }
    }

    init() {
        self.onboardFee = 0.0
        self.bridgeFee = 0.0
        self.adminStoragePath = /storage/flowEVMBridgeConfigAdmin
        self.coaStoragePath = /storage/evm
        self.bridgeAccessorPublicPath = /public/flowEVMBridgeAccessor

        self.account.storage.save(<-create Admin(), to: self.adminStoragePath)
    }
}
