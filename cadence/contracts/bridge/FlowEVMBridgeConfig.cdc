import "EVM"

/// This contract is used to store configuration information shared by FlowEVMBridge contracts
///
access(all) contract FlowEVMBridgeConfig {

    /// Amount of FLOW paid to onboard a Type or EVMAddress to the bridge
    access(all)
    var onboardFee: UFix64
    /// Amount of FLOW paid to bridge
    access(all)
    var bridgeFee: UFix64
    /// Mapping of Type to EVMAddress
    access(self)
    let typeToEVMAddress: {Type: EVM.EVMAddress}

    /* Path Constants */
    //
    /// StoragePath where bridge Cadence Owned Account is stored
    access(all)
    let coaStoragePath: StoragePath
    /// StoragePath where bridge config Admin is stored
    access(all)
    let adminStoragePath: StoragePath
    /// StoragePath where bridge EVM.BridgeAccessor is stored
    access(all)
    let bridgeAccessorStoragePath: StoragePath

    /* Events */
    //
    /// Emitted whenever the bridge fee is updated. The isOnboarding flag identifies which fee was updated
    ///
    access(all)
    event BridgeFeeUpdated(old: UFix64, new: UFix64, isOnboarding: Bool)

    /* Bridge Account Methods */
    //
    /// Enables bridge contracts to update the typeToEVMAddress mapping
    ///
    access(account)
    fun associateType(_ type: Type, with evmAddress: EVM.EVMAddress) {
        self.typeToEVMAddress[type] = evmAddress
    }

    /* Config Admin */
    //
    /// Admin resource enables updates to the bridge fees
    ///
    access(all)
    resource Admin {
        access(all)
        fun updateOnboardingFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.onboardFee, new: new, isOnboarding: true)
            FlowEVMBridgeConfig.onboardFee = new
        }
        access(all)
        fun updateBridgeFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.bridgeFee, new: new, isOnboarding: false)
            FlowEVMBridgeConfig.bridgeFee = new
        }
    }

    init() {
        self.onboardFee = 0.0
        self.bridgeFee = 0.0
        self.typeToEVMAddress = {}
        self.adminStoragePath = /storage/flowEVMBridgeConfigAdmin
        self.coaStoragePath = /storage/evm
        self.bridgeAccessorStoragePath = /storage/flowEVMBridgeAccessor

        self.account.storage.save(<-create Admin(), to: self.adminStoragePath)
    }
}
