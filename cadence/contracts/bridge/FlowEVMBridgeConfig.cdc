import "EVM"

/// This contract is used to store configuration information shared by FlowEVMBridge contracts
///
access(all)
contract FlowEVMBridgeConfig {

    /* --- Contract values --- */
    //
    /// Amount of FLOW paid to onboard a Type or EVMAddress to the bridge
    access(all)
    var onboardFee: UFix64
    /// Flat rate fee for all bridge requests
    access(all)
    var baseFee: UFix64
    /// Fee rate per storage unit consumed by bridged assets
    access(all)
    var storageRate: UFix64
    /// Mapping of Type to its associated EVMAddress as relevant to the bridge
    access(self)
    let typeToEVMAddress: {Type: EVM.EVMAddress}

    /* --- Path Constants --- */
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

    /* --- Events --- */
    //
    /// Emitted whenever the onboarding fee is updated
    ///
    access(all)
    event BridgeFeeUpdated(old: UFix64, new: UFix64, isOnboarding: Bool)
    /// Emitted whenever baseFee or storageRate is updated
    ///
    access(all)
    event StorageRateUpdated(old: UFix64, new: UFix64)

    /*************
        Getters
     *************/

    /// Retrieves the EVMAddress associated with a given Type if it has been onboarded to the bridge
    ///
    access(all)
    view fun getEVMAddressAssociated(with type: Type): EVM.EVMAddress? {
        return self.typeToEVMAddress[type]
    }

    /****************************
        Bridge Account Methods
     ****************************/

    /// Enables bridge contracts to update the typeToEVMAddress mapping
    ///
    access(account)
    fun associateType(_ type: Type, with evmAddress: EVM.EVMAddress) {
        self.typeToEVMAddress[type] = evmAddress
    }

    /*****************
        Config Admin
     *****************/

    /// Admin resource enables updates to the bridge fees
    ///
    access(all)
    resource Admin {

        /// Updates the onboarding fee
        ///
        /// @param new: UFix64 - new onboarding fee
        ///
        /// @emits BridgeFeeUpdated with the old and new rates and isOnboarding set to true
        access(all)
        fun updateOnboardingFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.onboardFee, new: new, isOnboarding: true)
            FlowEVMBridgeConfig.onboardFee = new
        }

        /// Updates the base fee
        ///
        /// @param new: UFix64 - new base fee
        ///
        /// @emits BridgeFeeUpdated with the old and new rates and isOnboarding set to false
        ///
        access(all)
        fun updateBaseFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.baseFee, new: new, isOnboarding: false)
            FlowEVMBridgeConfig.baseFee = new
        }

        /// Updates the storage rate
        ///
        /// @param new: UFix64 - new storage rate
        ///
        /// @emits StorageRateUpdated with the old and new rates
        /// 
        access(all)
        fun updateStorageRate(_ new: UFix64) {
            emit StorageRateUpdated(old: FlowEVMBridgeConfig.baseFee, new: new)
            FlowEVMBridgeConfig.baseFee = new
        }
    }

    init() {
        self.onboardFee = 0.0
        self.baseFee = 0.0
        self.storageRate = 0.0
        self.typeToEVMAddress = {}
        self.adminStoragePath = /storage/flowEVMBridgeConfigAdmin
        self.coaStoragePath = /storage/evm
        self.bridgeAccessorStoragePath = /storage/flowEVMBridgeAccessor

        self.account.storage.save(<-create Admin(), to: self.adminStoragePath)
    }
}
