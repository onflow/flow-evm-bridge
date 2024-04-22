import "EVM"

import "FlowToken"

import "EVMUtils"
import "FlowEVMBridgeHandlerInterfaces"

/// This contract is used to store configuration information shared by FlowEVMBridge contracts
///
access(all)
contract FlowEVMBridgeConfig {

    access(all) entitlement Fee

    /* --- Contract values --- */
    //
    /// Amount of FLOW paid to onboard a Type or EVMAddress to the bridge
    access(all)
    var onboardFee: UFix64
    /// Flat rate fee for all bridge requests
    access(all)
    var baseFee: UFix64
    /// Default ERC20.decimals() value
    access(all)
    let defaultDecimals: UInt8
    /// Mapping of Type to its associated EVMAddress as relevant to the bridge
    access(self)
    let typeToEVMAddress: {Type: EVM.EVMAddress}
    /// Reverse mapping of typeToEVMAddress. Note the EVMAddress is stored as a hex string since the EVMAddress type
    /// as of contract development is not a hashable or equatable type and making it so is not supported by Cadence
    access(self)
    let evmAddressHexToType: {String: Type}
    /// Mapping of Type to its associated EVMAddress as relevant to the bridge
    access(self)
    let typeToHandlers: @{Type: {FlowEVMBridgeHandlerInterfaces.TokenHandler}}

    /* --- Path Constants --- */
    //
    /// StoragePath where bridge Cadence Owned Account is stored
    access(all)
    let coaStoragePath: StoragePath
    /// StoragePath where bridge config Admin is stored
    access(all)
    let adminStoragePath: StoragePath
    /// StoragePath to store the Provider capability used as a bridge fee Provider
    access(all)
    let providerCapabilityStoragePath: StoragePath

    /* --- Events --- */
    //
    /// Emitted whenever the onboarding fee is updated
    ///
    access(all)
    event BridgeFeeUpdated(old: UFix64, new: UFix64, isOnboarding: Bool)
    // TODO
    access(all)
    event HandlerConfigured(targetType: Type, targetEVMAddress: String?, isEnabled: Bool)

    /*************
        Getters
     *************/

    /// Retrieves the EVMAddress associated with a given Type if it has been onboarded to the bridge
    ///
    access(all)
    view fun getEVMAddressAssociated(with type: Type): EVM.EVMAddress? {
        return self.typeToEVMAddress[type]
    }

    /// Retrieves the type associated with a given EVMAddress if it has been onboarded to the bridge
    ///
    access(all)
    view fun getTypeAssociated(with evmAddress: EVM.EVMAddress): Type? {
        let evmAddressHex = EVMUtils.getEVMAddressAsHexString(address: evmAddress)
        return self.evmAddressHexToType[evmAddressHex]
    }

    /****************************
        Bridge Account Methods
     ****************************/

    /// Enables bridge contracts to update the typeToEVMAddress mapping
    ///
    access(account)
    fun associateType(_ type: Type, with evmAddress: EVM.EVMAddress) {
        self.typeToEVMAddress[type] = evmAddress
        let evmAddressHex = EVMUtils.getEVMAddressAsHexString(address: evmAddress)
        self.evmAddressHexToType[evmAddressHex] = type
    }

    access(account)
    view fun typeHasHandler(_ type: Type): Bool {
        return self.typeToHandlers[type] != nil
    }

    access(account)
    view fun evmAddressHasHandler(_ evmAddress: EVM.EVMAddress): Bool {
        let associatedType = self.getTypeAssociated(with: evmAddress)
        return associatedType == nil ? self.typeHasHandler(associatedType!) : false
    }

    access(account)
    fun addHandler(_ handler: @{FlowEVMBridgeHandlerInterfaces.TokenHandler}) {
        pre {
            handler.getTargetType() != nil: "Cannot configure Handler without a target Cadence Type set"
            self.getEVMAddressAssociated(with: handler.getTargetType()!) == nil:
                "Cannot configure Handler for Type that has already been onboarded to the bridge"
            self.borrowHandler(handler.getTargetType()!) == nil:
                "Cannot configure Handler for Type that already has a Handler configured"
        }
        let type = handler.getTargetType()!
        var targetEVMAddressHex: String? = nil
        if let targetEVMAddress = handler.getTargetEVMAddress() {
            targetEVMAddressHex = EVMUtils.getEVMAddressAsHexString(address: targetEVMAddress)

            let associatedType = self.getTypeAssociated(with: targetEVMAddress)
            assert(
                associatedType == nil,
                message: "Handler target EVMAddress is already associated with a different Type"
            )
            self.associateType(type, with: targetEVMAddress)
        }

        emit HandlerConfigured(
            targetType: type,
            targetEVMAddress: targetEVMAddressHex,
            isEnabled: handler.isEnabled()
        )

        self.typeToHandlers[type] <-! handler
    }

    access(account)
    view fun borrowHandler(
        _ type: Type
    ): &{FlowEVMBridgeHandlerInterfaces.TokenHandler}? {
        return &self.typeToHandlers[type]
    }

    access(self)
    view fun borrowHandlerAdmin(
        _ type: Type
    ): auth(FlowEVMBridgeHandlerInterfaces.Admin) &{FlowEVMBridgeHandlerInterfaces.TokenHandler}? {
        return &self.typeToHandlers[type]
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
        ///
        access(Fee)
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
        access(Fee)
        fun updateBaseFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.baseFee, new: new, isOnboarding: false)
            FlowEVMBridgeConfig.baseFee = new
        }

        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setHandlerTargetEVMAddress(targetType: Type, targetEVMAddress: EVM.EVMAddress) {
            pre {
                FlowEVMBridgeConfig.getTypeAssociated(with: targetEVMAddress) == nil:
                    "EVM Address already associated with another Type"
            }
            FlowEVMBridgeConfig.borrowHandlerAdmin(targetType)
                ?.setTargetEVMAddress(targetEVMAddress)
                ?? panic("No handler found for target Type")
            emit HandlerConfigured(
                targetType: targetType,
                targetEVMAddress: EVMUtils.getEVMAddressAsHexString(address: targetEVMAddress),
                isEnabled: false
            )
        }

        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun enableHandler(targetType: Type) {
            let handler = FlowEVMBridgeConfig.borrowHandlerAdmin(targetType)
                ?? panic("No handler found for target Type")
            handler.enableBridging()

            let targetEVMAddressHex = EVMUtils.getEVMAddressAsHexString(
                    address: handler.getTargetEVMAddress() ?? panic("Handler cannot be enabled without a target EVM Address")
                )

            emit HandlerConfigured(
                targetType: handler.getTargetType()!,
                targetEVMAddress: targetEVMAddressHex,
                isEnabled: handler.isEnabled()
            )
        }
    }

    init() {
        self.onboardFee = 0.0
        self.baseFee = 0.0
        self.defaultDecimals = 18
        // Although $FLOW does not have ERC20 address, we associate the the Vault with the EVM address from which
        // EVM transfers originate
        // See FLIP #223 - https://github.com/onflow/flips/pull/225
        let flowOriginationAddress = EVM.EVMAddress(
                bytes: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]
            )
        let flowVaultType = Type<@FlowToken.Vault>()
        let flowOriginationAddressHex = EVMUtils.getEVMAddressAsHexString(address: flowOriginationAddress)
        self.typeToEVMAddress = { flowVaultType: flowOriginationAddress }
        self.evmAddressHexToType = { flowOriginationAddressHex: flowVaultType }
        self.typeToHandlers <- {}
        self.adminStoragePath = /storage/flowEVMBridgeConfigAdmin
        self.coaStoragePath = /storage/evm
        self.providerCapabilityStoragePath = /storage/bridgeFlowVaultProvider

        self.account.storage.save(<-create Admin(), to: self.adminStoragePath)
    }
}
