
import "Burner"
import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "FlowToken"

import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"
import "CrossVMToken"

/// This escrow contract handles the locking of fungible tokens that are bridged from Cadence to EVM and retrieval of
/// locked assets in escrow when they are bridged back to Cadence.
///
access(all) contract FlowEVMBridgeTokenEscrow {

    access(all) event LockerBurned(lockedType: Type, evmTokenAddress: String, lockerBalance: UFix64)

    /**********************
            Getters
    ***********************/

    /// Returns whether the Locker has been initialized for the given fungible token type
    ///
    access(all) view fun isInitialized(forType: Type): Bool {
        if let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: forType) {
            return self.account.storage.type(at: lockerPath) != nil
        }
        return false
    }

    /// Resolves the requested view type for the given FT type if it is locked and supports the requested view type
    ///
    /// @param tokenType: Type of the locked fungible tokens
    /// @param viewType: Type of the view to resolve
    ///
    /// @returns The resolved view as AnyStruct if the vault is locked and the view is supported, otherwise returns nil
    ///
    access(all) fun resolveLockedTokenView(tokenType: Type, viewType: Type): AnyStruct? {
        if let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: tokenType) {
            // The Locker implements Resolver, which has basic resolveView functionality
            return self.account.storage.borrow<&Locker>(from: lockerPath)?.resolveView(viewType) ?? nil
        }
        return nil
    }

    /**********************
        Bridge Methods
    ***********************/

    /// Initializes the Locker for the given fungible token type if it hasn't been initialized yet
    ///
    access(account) fun initializeEscrow(forType: Type, evmTokenAddress: EVM.EVMAddress) {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: forType)
            ?? panic("Problem deriving locker path")
        if self.account.storage.type(at: lockerPath) != nil {
            panic("Collision at derived Locker path for type: ".concat(forType.identifier))
        }

        // Call to the ERC20 contract to get contract values
        let name = FlowEVMBridgeUtils.getName(evmContractAddress: evmTokenAddress)
        let symbol = FlowEVMBridgeUtils.getSymbol(evmContractAddress: evmTokenAddress)
        let decimals = FlowEVMBridgeUtils.getTokenDecimals(evmContractAddress: evmTokenAddress)

        // Create the Locker, lock a new vault of given type and save at the derived path
        let locker <- create Locker(name: name, symbol: symbol, decimals: decimals, lockedType: forType, evmTokenAddress: evmTokenAddress)
        self.account.storage.save(<-locker, to: lockerPath)
    }

    /// Locks the fungible tokens in escrow
    ///
    access(account) fun lockTokens(_ vault: @{FungibleToken.Vault}): UInt64 {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: vault.getType())
            ?? panic("Problem deriving locker path")
        let locker = self.account.storage.borrow<&Locker>(from: lockerPath)
            ?? panic("Locker doesn't exist")
        let preStorageSnapshot = self.account.storage.used
        locker.deposit(from: <-vault)
        let postStorageSnapshot = self.account.storage.used
        return postStorageSnapshot - preStorageSnapshot
    }

    /// Unlocks the tokens of the given type and amount, reverting if it isn't in escrow
    ///
    access(account) fun unlockTokens(type: Type, amount: UFix64): @{FungibleToken.Vault} {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: type)
            ?? panic("Problem deriving locker path")
        let locker = self.account.storage.borrow<auth(FungibleToken.Withdraw) &Locker>(from: lockerPath)
            ?? panic("Locker doesn't exist")
        return <-locker.withdraw(amount: amount)
    }

    /*********************
            Locker
    *********************/

    /// The resource managing the locking & unlocking of FTs via this contract's interface
    ///
    access(all) resource Locker : CrossVMToken.EVMFTVault {
        /// Field that tracks the balance of a vault
        access(all) var balance: UFix64
        /// Corresponding name assigned in the tokens' corresponding ERC20 contract
        access(all) let name: String
        /// Corresponding symbol assigned in the tokens' corresponding ERC20 contract
        access(all) let symbol: String
        /// Corresponding decimals assigned in the tokens' corresponding ERC20 contract. While Cadence support floating
        /// point numbers, EVM does not, so we need to keep track of the decimals to convert between the two.
        access(all) let decimals: UInt8
        /// The type of FT this Locker escrows
        access(all) let lockedType: Type
        /// Corresponding ERC721 address for the locked NFTs
        access(all) let evmTokenAddress: EVM.EVMAddress
        // Vault to hold all relevant locked FTs
        access(self) let lockedVault: @{FungibleToken.Vault}


        init(name: String, symbol: String, decimals: UInt8, lockedType: Type, evmTokenAddress: EVM.EVMAddress) {
            self.decimals = decimals
            self.balance = 0.0
            self.name = name
            self.symbol = symbol
            self.lockedType = lockedType
            self.evmTokenAddress = evmTokenAddress

            let createVault = FlowEVMBridgeUtils.getCreateEmptyVaultFunction(forType: lockedType)
                ?? panic("Could not find createEmptyVault function for given type")
            self.lockedVault <- createVault(lockedType)
            // Locked Vaults must accept their own type as Lockers escrow Vaults on a 1:1 type basis
            assert(
                self.lockedVault.isSupportedVaultType(type: lockedType),
                message: "Locked Vault does not accept its own type"
            )
        }

        access(all) view fun getEVMContractAddress(): EVM.EVMAddress {
            return self.evmTokenAddress
        }

        /// Returns the number of locked tokens in this locker
        ///
        access(all) view fun getLockedBalance(): UFix64 {
            return self.lockedVault.balance
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return self.lockedVault.isAvailableToWithdraw(amount: amount)
        }

        /// Returns a map of supported FT types - at the moment Lockers only support the lockedNFTType defined by
        /// their contract
        ///
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {
                self.lockedType: self.isSupportedVaultType(type: self.lockedType)
            }
        }

        /// Returns true if the token Vault type is supported
        ///
        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return type == self.lockedType
        }

        /// Deposits the given token vault into this locker
        ///
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            self.balance = self.balance + from.balance
            self.lockedVault.deposit(from: <-from)
        }

        /// Creates a new instance of the locked Vault, **not** the encapsulating Locker
        ///
        access(all) fun createEmptyVault(): @{FungibleToken.Vault} {
            return <-create Locker(
                name: self.name,
                symbol: self.symbol,
                decimals: self.decimals,
                lockedType: self.lockedType,
                evmTokenAddress: self.evmTokenAddress
            )
        }

        /// Returns the views supported by the locked Vault
        ///
        access(all) view fun getViews(): [Type] {
            return self.lockedVault.getViews()
        }

        /// Resolves the requested view type on the locked FT if it supports the requested view type
        ///
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return self.lockedVault.resolveView(view)
        }

        /// Withdraws an amount of tokens from this locker, removing it from the vault and returning it
        ///
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            self.balance = self.balance - amount
            return <-self.lockedVault.withdraw(amount: amount)
        }

        /// Emits an event notifying that the Locker has been burned with information about the locked vault
        ///
        access(contract) fun burnCallback() {
            emit LockerBurned(
                lockedType: self.lockedType,
                evmTokenAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: self.evmTokenAddress),
                lockerBalance: self.balance
            )
            self.balance = 0.0
        }
    }
}
