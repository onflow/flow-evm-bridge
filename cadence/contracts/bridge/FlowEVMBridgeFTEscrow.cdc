import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "FlowToken"

import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"
import "CrossVMNFT"

/// This escrow contract handles the locking of assets that are bridged from Flow to EVM and retrieval of locked
/// assets in escrow when they are bridged back to Flow.
///
access(all) contract FlowEVMBridgeFTEscrow {

    /**********************
            Getters
    ***********************/

    /// Returns whether the Locker has been initialized for the given NFT type
    ///
    access(all)
    view fun isInitialized(forType: Type): Bool {
        if let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: forType) {
            return self.account.storage.type(at: lockerPath) != nil
        }
        return false
    }

    /// Resolves the requested view type for the given FT type if it is locked and supports the requested view type
    ///
    /// @param nftType: Type of the locked NFT
    /// @param viewType: Type of the view to resolve
    /// @param id: ID of the locked NFT
    ///
    /// @returns The resolved view as AnyStruct if the NFT is locked and the view is supported, otherwise returns nil
    ///
    access(all)
    fun resolveLockedFTView(ftType: Type, viewType: Type): AnyStruct? {
        if let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: ftType) {
            if let locker = self.account.storage.borrow<&Locker>(from: lockerPath) {
                return locker.borrowViewResolver()
                if let cadenceID = locker.getCadenceID(from: id) {
                    // The locker implements Resolver, which has basic resolveView functionality
                    return locker.resolveView(viewType) ?? nil
                }
            }
        }
        return nil
    }

    /**********************
        Bridge Methods
    ***********************/

    /// Initializes the Locker for the given FT type if it hasn't been initialized yet
    ///
    access(account)
    fun initializeEscrow(forType: Type, erc20Address: EVM.EVMAddress) {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: forType)
            ?? panic("Problem deriving locker path")
        if self.account.storage.type(at: lockerPath) != nil {
            return
        }
        let locker <- create Locker(lockedType: forType, erc20Address: erc20Address)
        self.account.storage.save(<-locker, to: lockerPath)
    }

    /// Locks the FT in escrow
    ///
    access(account)
    fun lockFT(_ ft: @{FungibleToken.Vault}): UInt64 {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: ft.getType())
            ?? panic("Problem deriving locker path")
        let locker = self.account.storage.borrow<&Locker>(from: lockerPath)
            ?? panic("Locker doesn't exist")
        let preStorageSnapshot = self.account.storage.used
        locker.deposit(vault: <-ft)
        let postStorageSnapshot = self.account.storage.used
        return postStorageSnapshot - preStorageSnapshot
    }

    /// Unlocks the NFT of the given type and ID, reverting if it isn't in escrow
    ///
    access(account)
    fun unlockFT(type: Type, amount: UFix64): @{NonFungibleToken.NFT} {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: type)
            ?? panic("Problem deriving locker path")
        let locker = self.account.storage.borrow<auth(FungibleToken.Withdraw) &Locker>(from: lockerPath)
            ?? panic("Locker doesn't exist")
        return <- locker.withdraw(withdrawID: id)
    }

    /*********************
            Locker
    *********************/

    /// The resource managing the locking & unlocking of FTs via this contract's interface
    ///
    access(all) resource Locker : FungibleToken.Vault {
        /// The type of FT this Locker escrows
        access(all)
        let lockedType: Type
        /// Corresponding ERC721 address for the locked NFTs
        access(all)
        let erc20Address: EVM.EVMAddress
        // Vault to hold all relevant locked FTs
        access(self)
        let lockedVault: @{FungibleToken.Vault}

        /// Field that tracks the balance of a vault
        access(all) var balance: UFix64

        init(lockedType: Type, erc20Address: EVM.EVMAddress) {
            self.lockedType = lockedType
            self.erc20Address = erc20Address
            let contractAddress = getContractAddress(fromType: lockedType)
            let contractName = getContractName(fromType: lockedType)
            let borrowedContract = getAccount(contractAddress).contracts.borrow<&FungibleToken>(name: contractName) ?? panic("Provided contract is not a FungibleToken")
            let ftVaultData = borrowedContract.resolveContractView(resourceType: nil,viewType: Type<FungibleTokenMetadataViews.FTVaultData) as! as! FungibleTokenMetadataViews.FTVaultData?
            self.lockedVault <- ftVaultData!.createEmptyVaultFunction()
        }

        // Returns the relevant fungible token contract
        //
        access(all)
        view fun borrowContract(): &FungibleToken {
            let contractAddress = getContractAddress(fromType: self.lockedType)
            let contractName = getContractName(fromType: self.lockedType)
            return getAccount(contractAddress).contracts.borrow<&FungibleToken>(name: contractName) ?? panic("Provided contract is not a FungibleToken")
        }

        /// Returns the number of locked tokens in this locker
        ///
        access(all)
        view fun getBalance(): UFix64 {
            return self.lockedVault.balance
        }

        /// Returns a map of supported FT types - at the moment Lockers only support the lockedNFTType defined by
        /// their contract
        ///
        access(all)
        view fun getSupportedFTTypes(): {Type: Bool} {
            return {
                self.lockedType: self.isSupportedFTType(type: self.lockedType)
            }
        }

        /// Returns true if the NFT type is supported
        ///
        access(all)
        view fun isSupportedFTType(type: Type): Bool {
            return type == self.lockedType
        }

        /// Deposits the given FT vault into this locker
        ///
        access(all)
        fun deposit(from: @{FungibleToken.Vault}) {
            self.lockedVault.deposit(from: from)
        }

        access(all)
        view fun getSupportedVaultTypes(): {Type: Bool} {
            return {
                self.lockedType: self.isSupportedFTType(type: self.lockedType)
            }
        }

        /// Withdraws an amount of FT from this locker, removing it from the vault and returning it
        ///
        access(FungibleToken.Withdraw)
        fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            // Should not happen, but prevent potential underflow
            assert(self.lockedVault.balance < )

            return <-(self.lockedVault.withdraw(amount: amount) as! @{FungibleToken.Vault})
        }

        /// createEmptyVault allows any user to create a new Vault that has a zero balance
        ///
        access(all) fun createEmptyVault(): @{Vault} {
            let ftVaultData = self.borrowContract().resolveContractView(resourceType: nil,viewType: Type<FungibleTokenMetadataViews.FTVaultData) as! as! FungibleTokenMetadataViews.FTVaultData?
            let emptyVault <- ftVaultData!.createEmptyVaultFunction()
            return <-emptyVault
        }

        access(all) view fun getViews(): [Type] {
            return self.lockedVault.getViews()
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return self.lockedVault.resolveView(view)
        }
    }
}
