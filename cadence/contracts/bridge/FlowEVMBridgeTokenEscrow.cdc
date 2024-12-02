
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

    /**********************
            Getters
    ***********************/

    /// Returns whether the Locker has been initialized for the given fungible token type
    ///
    /// @param forType: Type of the locked fungible tokens
    ///
    /// @returns true if the Locker has been initialized for the given fungible token type, otherwise false
    ///
    access(all) view fun isInitialized(forType: Type): Bool {
        return self.borrowLocker(forType: forType) != nil
    }

    /// Returns the balance of locked tokens for the given fungible token type
    ///
    /// @param tokenType: Type of the locked fungible tokens
    ///
    /// @returns The balance of locked tokens for the given fungible token type or nil if the locker doesn't exist
    ///
    access(all) view fun getLockedTokenBalance(tokenType: Type): UFix64? {
        return self.borrowLocker(forType: tokenType)?.getLockedBalance() ?? nil
    }

    /// Returns the type of the locked vault for the given fungible token type
    ///
    /// @param tokenType: Type of the locked fungible tokens
    ///
    /// @returns The type of the locked vault for the given fungible token type or nil if the locker doesn't exist
    ///
    access(all) view fun getViews(tokenType: Type): [Type]? {
        return self.borrowLocker(forType: tokenType)?.getViews() ?? []
    }

    /**********************
        Bridge Methods
    ***********************/

    /// Initializes the Locker for the given fungible token type if it hasn't been initialized yet
    ///
    access(account) fun initializeEscrow(
        with vault: @{FungibleToken.Vault},
        name: String,
        symbol: String,
        decimals: UInt8,
        evmTokenAddress: EVM.EVMAddress
    ) {
        pre {
            vault.balance == 0.0:
            "Vault contains a balance=".concat(vault.balance.toString())
                .concat(" - can only initialize Escrow with an empty vault")
        }
        let lockedType = vault.getType()
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: lockedType)
            ?? panic("Problem deriving Locker path for Vault type identifier=".concat(lockedType.identifier))
        if self.account.storage.type(at: lockerPath) != nil {
            panic("Token Locker already stored at storage path=".concat(lockedType.identifier))
        }

        // Create the Locker, lock a new vault of given type and save at the derived path
        let locker <- create Locker(
            name: name,
            symbol: symbol,
            decimals: decimals,
            lockedVault: <-vault,
            evmTokenAddress: evmTokenAddress
        )
        self.account.storage.save(<-locker, to: lockerPath)
    }

    /// Locks the fungible tokens in escrow returning the storage used by locking the Vault
    ///
    access(account) fun lockTokens(_ vault: @{FungibleToken.Vault}): UInt64 {
        let locker = self.borrowLocker(forType: vault.getType())
            ?? panic("Locker doesn't exist for given type=".concat(vault.getType().identifier))

        let preStorageSnapshot = self.account.storage.used
        locker.deposit(from: <-vault)
        let postStorageSnapshot = self.account.storage.used

        // Return the amount of storage used by the locker after storing the NFT
        if postStorageSnapshot < preStorageSnapshot {
            // Due to atree inlining, account storage usage may counterintuitively decrease at times - return 0
            return 0
        } else {
            // Otherwise, return the storage usage delta
            return postStorageSnapshot - preStorageSnapshot
        }
    }

    /// Unlocks the tokens of the given type and amount, reverting if it isn't in escrow
    ///
    access(account) fun unlockTokens(type: Type, amount: UFix64): @{FungibleToken.Vault} {
        let locker = self.borrowLocker(forType: type)
            ?? panic("Locker doesn't exist for given type=".concat(type.identifier))
        return <- locker.withdraw(amount: amount)
            
    }

    /// Retrieves an entitled locker for the given type or nil if it doesn't exist
    ///
    access(self) view fun borrowLocker(forType: Type): auth(FungibleToken.Withdraw) &Locker? {
        if let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: forType) {
            if self.account.storage.type(at: lockerPath) == Type<@Locker>() {
                return self.account.storage.borrow<auth(FungibleToken.Withdraw) &Locker>(from: lockerPath)
            }
        }
        return nil
    }

    /*********************
            Locker
    *********************/

    /// The resource managing the locking & unlocking of FTs via this contract's interface.
    ///
    access(all) resource Locker : CrossVMToken.EVMTokenInfo, FungibleToken.Receiver, FungibleToken.Provider, ViewResolver.Resolver {
        /// Corresponding name assigned in the tokens' corresponding ERC20 contract
        access(all) let name: String
        /// Corresponding symbol assigned in the tokens' corresponding ERC20 contract
        access(all) let symbol: String
        /// Corresponding decimals assigned in the tokens' corresponding ERC20 contract. While Cadence support floating
        /// point numbers, EVM does not, so we need to keep track of the decimals to convert between the two.
        access(all) let decimals: UInt8
        /// Corresponding ERC20 address for the locked tokens
        access(all) let evmTokenAddress: EVM.EVMAddress
        // Vault to hold all locked tokens
        access(self) let lockedVault: @{FungibleToken.Vault}


        init(name: String, symbol: String, decimals: UInt8, lockedVault: @{FungibleToken.Vault}, evmTokenAddress: EVM.EVMAddress) {
            self.decimals = decimals
            self.name = name
            self.symbol = symbol
            self.evmTokenAddress = evmTokenAddress

            self.lockedVault <- lockedVault
            // Locked Vaults must accept their own type as Lockers escrow Vaults on a 1:1 type basis
            assert(
                self.lockedVault.isSupportedVaultType(type: self.lockedVault.getType()),
                message: "Locked Vault does not accept its own type=".concat(self.lockedVault.getType().identifier)
            )
        }

        /// Gets the ERC20 name value
        access(all) view fun getName(): String {
            return self.name
        }
        /// Gets the ERC20 symbol value
        access(all) view fun getSymbol(): String {
            return self.symbol
        }
        /// Gets the ERC20 decimals value
        access(all) view fun getDecimals(): UInt8 {
            return self.decimals
        }
        /// Get the EVM contract address of the locked Vault's corresponding ERC20 contract address
        ///
        access(all) view fun getEVMContractAddress(): EVM.EVMAddress {
            return self.evmTokenAddress
        }

        /// Returns the balance of tokens in the locked Vault
        ///
        access(all) view fun getLockedBalance(): UFix64 {
            return self.lockedVault.balance
        }

        /// Returns the type of the locked vault
        ///
        access(all) view fun getLockedType(): Type {
            return self.lockedVault.getType()
        }

        /// Function to ask a provider if a specific amount of tokens is available to be withdrawn from the locked vault
        ///
        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return self.lockedVault.isAvailableToWithdraw(amount: amount)
        }

        /// Returns a mapping of vault types that this locker accepts. This Locker will only accept Vaults of the same
        ///
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {self.lockedVault.getType(): true}
        }

        /// Returns whether or not the given type is accepted by the Receiver
        ///
        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
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

        /// Deposits the given token vault into the contained locked Vault
        ///
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            self.lockedVault.deposit(from: <-from)
        }

        /// Withdraws an amount of tokens from this locker, removing it from the vault and returning it
        ///
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            return <-self.lockedVault.withdraw(amount: amount)
        }
    }
}
