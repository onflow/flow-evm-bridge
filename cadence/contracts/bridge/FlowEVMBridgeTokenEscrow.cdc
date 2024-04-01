
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
        if let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: tokenTypeType) {
            if let locker = self.account.storage.borrow<&Locker>(from: lockerPath) {
                return locker.borrowViewResolver()
                if let cadenceID = locker.getCadenceID(from: id) {
                    // The locker implements Resolver, which has basic resolveView functionality
                    return locker.resolveView(viewType)
                }
            }
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
            panic("Collision at derived Locker path for type: ".concat(forType.toString()))
        }

        // Call to the ERC20 contract to get the decimals of the token
        let decimalsResult = FlowEVMBridgeUtils.call(
            signature: "decimals()",
            targetEVMAddress: evmTokenAddress,
            args: [],
            gasLimit: 12_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(decimalsResult.status == EVM.Result.successful, message: "Failed to get decimals from ERC20 contract")
        let decimals = EVM.decodeABI(types: [EVM.EVMAddress], data: decimalsResult.data) as [UInt8]
        assert(decimals.length == 1, message: "Problem decoding result of decimals() call to ERC20 contract")

        // Create the Locker, lock a new vault of given type and save at the derived path
        let locker <- create Locker(lockedType: forType, evmTokenAddress: erc20Address, decimals: decimals[0])
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
        locker.deposit(vault: <-vault)
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
    access(all) resource Locker : BridgeTokenLocker, CrossVMToken.EVMFTVault {
        /// Field that tracks the balance of a vault
        access(all) var balance: UFix64
        /// The type of FT this Locker escrows
        access(all) let lockedType: Type
        /// Corresponding ERC721 address for the locked NFTs
        access(all) let evmTokenAddress: EVM.EVMAddress
        /// Corresponding decimals assigned in the tokens' corresponding ERC20 contract. While Cadence support floating
        /// point numbers, EVM does not, so we need to keep track of the decimals to convert between the two.
        access(all) let decimals: UInt8
        // Vault to hold all relevant locked FTs
        access(self) let lockedVault: @{FungibleToken.Vault}


        init(lockedType: Type, evmTokenAddress: EVM.EVMAddress, decimals: UInt8) {
            self.lockedType = lockedType
            self.evmTokenAddress = evmTokenAddress
            self.decimals = decimals

            let createVault = FlowEVMBridgeUtils.getCreateEmptyVaultFunction(forType: type)
                ?? panic("Could not find createEmptyVault function for given type")
            self.lockedVault <- createVault(lockedType)
            // Locked Vaults must accept their own type as Lockers escrow Vaults on a 1:1 type basis
            assert(
                self.lockedVault.isSupportedVaultType(type: lockedType),
                message: "Locked Vault does not accept its own type"
            )
        }

        /// Returns the number of locked tokens in this locker
        ///
        access(all) view fun getLockedBalance(): UFix64 {
            return self.lockedVault.balance
        }

        /// Returns a map of supported FT types - at the moment Lockers only support the lockedNFTType defined by
        /// their contract
        ///
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {
                self.lockedType: self.isSupportedFTType(type: self.lockedType)
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
            self.lockedVault.deposit(from: from)
        }

        /// Withdraws an amount of tokens from this locker, removing it from the vault and returning it
        ///
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            self.balance = self.balance - amount
            return <-self.lockedVault.withdraw(amount: amount)
        }

        /// Creates a new instance of the locked Vault, **not** the encapsulating Locker
        ///
        access(all) fun createEmptyVault(): @{Vault} {
            return self.lockedVault.createEmptyVault()
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

        /// Emits an event notifying that the Locker has been burned with information about the locked vault
        ///
        access(contract) fun burnCallback() {
            emit LockerBurned(lockedType: self.lockedType, evmTokenAddress: self.evmTokenAddress, lockerBalance: self.balance)
            self.balance = 0.0
        }
    }
}