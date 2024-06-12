import "EVM"

import "FlowToken"

import "EVMUtils"
import "FlowEVMBridgeHandlerInterfaces"

/// This contract is used to store configuration information shared by FlowEVMBridge contracts
///
access(all)
contract FlowEVMBridgeConfig {

    /******************
        Entitlements
    *******************/

    access(all) entitlement Fee
    access(all) entitlement Pause

    /*************
        Fields
    **************/

    /// Amount of FLOW paid to onboard a Type or EVMAddress to the bridge
    access(all)
    var onboardFee: UFix64
    /// Flat rate fee for all bridge requests
    access(all)
    var baseFee: UFix64
    /// Default ERC20.decimals() value
    access(all)
    let defaultDecimals: UInt8
    /// Flag enabling pausing of bridge operations
    access(self)
    var paused: Bool
    /// Mapping of Type to its associated EVMAddress as relevant to the bridge
    access(self)
    let typeToEVMAddress: {Type: EVM.EVMAddress}
    /// Reverse mapping of typeToEVMAddress. Note the EVMAddress is stored as a hex string since the EVMAddress type
    /// as of contract development is not a hashable or equatable type and making it so is not supported by Cadence
    access(self)
    let evmAddressHexToType: {String: Type}
    /// Mapping of Type to its associated EVMAddress as relevant to the bridge
    access(self)
    let typeToTokenHandlers: @{Type: {FlowEVMBridgeHandlerInterfaces.TokenHandler}}

    /********************
        Path Constants
    *********************/

    /// StoragePath where bridge Cadence Owned Account is stored
    access(all)
    let coaStoragePath: StoragePath
    /// StoragePath where bridge config Admin is stored
    access(all)
    let adminStoragePath: StoragePath
    /// PublicPath where a public Capability on the bridge config Admin is exposed
    access(all)
    let adminPublicPath: PublicPath
    /// StoragePath to store the Provider capability used as a bridge fee Provider
    access(all)
    let providerCapabilityStoragePath: StoragePath

    /*************
        Events
    **************/

    /// Emitted whenever the onboarding fee is updated
    ///
    access(all)
    event BridgeFeeUpdated(old: UFix64, new: UFix64, isOnboarding: Bool)
    /// Emitted whenever a TokenHandler is configured
    ///
    access(all)
    event HandlerConfigured(targetType: Type, targetEVMAddress: String?, isEnabled: Bool)
    /// Emitted whenever the bridge is paused
    ///
    access(all)
    event PauseStatusUpdated(paused: Bool)

    /*************
        Getters
     *************/

    /// Returns whether the bridge is paused
    access(all)
    view fun isPaused(): Bool {
        return self.paused
    }

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
        pre {
            self.getEVMAddressAssociated(with: type) == nil: "Type already associated with an EVMAddress"
            self.getTypeAssociated(with: evmAddress) == nil: "EVMAddress already associated with a Type"
        }
        self.typeToEVMAddress[type] = evmAddress
        let evmAddressHex = EVMUtils.getEVMAddressAsHexString(address: evmAddress)
        self.evmAddressHexToType[evmAddressHex] = type
    }

    /// Returns whether the given Type has a TokenHandler configured
    ///
    access(account)
    view fun typeHasTokenHandler(_ type: Type): Bool {
        return self.typeToTokenHandlers[type] != nil
    }

    /// Returns whether the given EVMAddress has a TokenHandler configured
    ///
    access(account)
    view fun evmAddressHasTokenHandler(_ evmAddress: EVM.EVMAddress): Bool {
        let associatedType = self.getTypeAssociated(with: evmAddress)
        return associatedType != nil ? self.typeHasTokenHandler(associatedType!) : false
    }

    /// Adds a TokenHandler to the bridge configuration
    ///
    access(account)
    fun addTokenHandler(_ handler: @{FlowEVMBridgeHandlerInterfaces.TokenHandler}) {
        pre {
            handler.getTargetType() != nil: "Cannot configure Handler without a target Cadence Type set"
            self.getEVMAddressAssociated(with: handler.getTargetType()!) == nil:
                "Cannot configure Handler for Type that has already been onboarded to the bridge"
            self.borrowTokenHandler(handler.getTargetType()!) == nil:
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

        self.typeToTokenHandlers[type] <-! handler
    }

    /// Returns an unentitled reference to the TokenHandler associated with the given Type
    ///
    access(account)
    view fun borrowTokenHandler(
        _ type: Type
    ): &{FlowEVMBridgeHandlerInterfaces.TokenHandler}? {
        return &self.typeToTokenHandlers[type]
    }

    /// Returns an entitled reference to the TokenHandler associated with the given Type
    ///
    access(self)
    view fun borrowTokenHandlerAdmin(
        _ type: Type
    ): auth(FlowEVMBridgeHandlerInterfaces.Admin) &{FlowEVMBridgeHandlerInterfaces.TokenHandler}? {
        return &self.typeToTokenHandlers[type]
    }

    /*****************
        Config Admin
     *****************/

    /// Admin resource enables updates to the bridge fees
    ///
    access(all)
    resource Admin {

        /// Sets the TokenMinter for the given Type. If a TokenHandler does not exist for the given Type, the operation
        /// reverts. The provided minter must be of the expected type for the TokenHandler and the handler cannot have
        /// a minter already set.
        ///
        /// @param targetType: Cadence type indexing the relevant TokenHandler
        /// @param minter: TokenMinter minter to set for the TokenHandler
        ///
        access(all)
        fun setTokenHandlerMinter(targetType: Type, minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}) {
            pre {
                FlowEVMBridgeConfig.typeHasTokenHandler(targetType):
                    "Cannot set minter for Type that does not have a TokenHandler configured"
            }
            let handler = FlowEVMBridgeConfig.borrowTokenHandlerAdmin(targetType)
                ?? panic("No handler found for target Type")
            assert(minter.getType() == handler.getExpectedMinterType(), message: "Invalid minter type")

            handler.setMinter(<-minter)
        }

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

        /// Pauses the bridge, preventing all bridge operations
        ///
        access(Pause)
        fun pauseBridge() {
            if FlowEVMBridgeConfig.isPaused() {
                return
            }
            FlowEVMBridgeConfig.paused = true
            emit PauseStatusUpdated(paused: true)
        }

        /// Unpauses the bridge, allowing bridge operations to resume
        ///
        access(Pause)
        fun unpauseBridge() {
            if !FlowEVMBridgeConfig.isPaused() {
                return
            }
            FlowEVMBridgeConfig.paused = false
            emit PauseStatusUpdated(paused: false)
        }

        /// Sets the target EVM contract address on the handler for a given Type, associating the Cadence type with the
        /// provided EVM address. If a TokenHandler does not exist for the given Type, the operation reverts.
        ///
        /// @param targetType: Cadence type to associate with the target EVM address
        /// @param targetEVMAddress: target EVM address to associate with the Cadence type
        ///
        /// @emits HandlerConfigured with the target Type, target EVM address, and whether the handler is enabled
        ///
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setHandlerTargetEVMAddress(targetType: Type, targetEVMAddress: EVM.EVMAddress) {
            pre {
                FlowEVMBridgeConfig.getTypeAssociated(with: targetEVMAddress) == nil:
                    "EVM Address already associated with another Type"
            }
            let handler = FlowEVMBridgeConfig.borrowTokenHandlerAdmin(targetType)
                ?? panic("No handler found for target Type")
            handler.setTargetEVMAddress(targetEVMAddress)

            if FlowEVMBridgeConfig.getEVMAddressAssociated(with: targetType) == nil {
                FlowEVMBridgeConfig.associateType(targetType, with: targetEVMAddress)
            }
            assert(
                FlowEVMBridgeConfig.getEVMAddressAssociated(with: targetType)!.bytes == targetEVMAddress.bytes,
                message: "Problem associating target Type and target EVM Address"
            )

            emit HandlerConfigured(
                targetType: targetType,
                targetEVMAddress: EVMUtils.getEVMAddressAsHexString(address: targetEVMAddress),
                isEnabled: handler.isEnabled()
            )
        }

        /// Enables the TokenHandler for the given Type. If a TokenHandler does not exist for the given Type, the
        /// operation reverts.
        ///
        /// @param targetType: Cadence type indexing the relevant TokenHandler
        ///
        /// @emits HandlerConfigured with the target Type, target EVM address, and whether the handler is enabled
        ///
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun enableHandler(targetType: Type) {
            let handler = FlowEVMBridgeConfig.borrowTokenHandlerAdmin(targetType)
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
        self.paused = false

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

        self.typeToTokenHandlers <- {}

        self.adminStoragePath = /storage/flowEVMBridgeConfigAdmin
        self.adminPublicPath = /public/flowEVMBridgeConfigAdmin
        self.coaStoragePath = /storage/evm
        self.providerCapabilityStoragePath = /storage/bridgeFlowVaultProvider

        // Create & save Admin, issuing a public unentitled Admin Capability
        self.account.storage.save(<-create Admin(), to: self.adminStoragePath)
        let adminCap = self.account.capabilities.storage.issue<&Admin>(self.adminStoragePath)
        self.account.capabilities.publish(adminCap, at: self.adminPublicPath)
    }
}
