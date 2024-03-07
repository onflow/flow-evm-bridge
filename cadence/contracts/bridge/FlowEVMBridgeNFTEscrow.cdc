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
access(all) contract FlowEVMBridgeNFTEscrow {

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


    /// Retrieves a reference to the NFT with the given ID
    ///
    /// @param id ID of the NFT to retrieve
    ///
    /// @returns Reference to the NFT if it exists
    ///
    access(all)
    view fun borrowLockedNFT(type: Type, id: UInt64): &{NonFungibleToken.NFT}? {
        if let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: type) {
            if let locker = self.account.storage.borrow<&Locker>(from: lockerPath) {
                return locker.borrowNFT(id)
            }
        }
        return nil
    }

    /// Returns whether an NFT with the given ID is locked
    ///
    /// @param id ID of the NFT to check
    ///
    /// @returns True if the NFT is locked, false otherwise
    ///
    access(all)
    view fun isLocked(type: Type, id: UInt64): Bool {
        return self.borrowLockedNFT(type: type, id: id) != nil
    }

    access(all)
    view fun getLockedCadenceID(type: Type, evmID: UInt256): UInt64? {
        if let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: type) {
            if let locker = self.account.storage.borrow<&Locker>(from: lockerPath) {
                return locker.getCadenceID(from: evmID)
            }
        }
        return nil
    }

    /**********************
        Bridge Methods
    ***********************/

    access(account)
    fun initializeEscrow(forType: Type, erc721Address: EVM.EVMAddress) {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: forType)
            ?? panic("Problem deriving locker path")
        if self.account.storage.type(at: lockerPath) != nil {
            return
        }
        let locker <- create Locker(lockedType: forType, erc721Address: erc721Address)
        self.account.storage.save(<-locker, to: lockerPath)
    }

    access(account) fun lockNFT(_ nft: @{NonFungibleToken.NFT}): UInt64 {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: nft.getType())
            ?? panic("Problem deriving locker path")
        let locker = self.account.storage.borrow<&Locker>(from: lockerPath)
            ?? panic("Locker doesn't exist")
        let preStorageSnapshot = self.account.storage.used
        locker.deposit(token: <-nft)
        let postStorageSnapshot = self.account.storage.used
        return postStorageSnapshot - preStorageSnapshot
    }

    access(account)
    fun unlockNFT(type: Type, id: UInt64): @{NonFungibleToken.NFT} {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: type)
            ?? panic("Problem deriving locker path")
        let locker = self.account.storage.borrow<auth(NonFungibleToken.Withdraw) &Locker>(from: lockerPath)
            ?? panic("Locker doesn't exist")
        return <- locker.withdraw(withdrawID: id)
    }

    /*********************
            Locker
    *********************/

    /// The resource managing the locking & unlocking of NFTs via this contract's interface
    ///
    access(all) resource Locker : CrossVMNFT.EVMNFTCollection, NonFungibleToken.Collection {
        /// The type of NFTs this Locker escrows
        access(all)
        let lockedType: Type
        /// Corresponding ERC721 address for the locked NFTs
        access(all)
        let erc721Address: EVM.EVMAddress
        /// Count of locked NFTs as lockedNFTs.length may exceed computation limits
        access(self)
        var lockedNFTCount: Int
        /// Indexed on NFT UUID to prevent collisions
        access(self)
        let lockedNFTs: @{UInt64: {NonFungibleToken.NFT}}
        /// Maps EVM NFT ID to Flow NFT ID, covering cross-VM project NFTs
        access(self)
        let evmIDToFlowID: {UInt256: UInt64}

        init(lockedType: Type, erc721Address: EVM.EVMAddress) {
            self.lockedType = lockedType
            self.erc721Address = erc721Address
            self.lockedNFTCount = 0
            self.lockedNFTs <- {}
            self.evmIDToFlowID = {}
        }

        /// Returns the number of locked NFTs
        ///
        access(all)
        view fun getLength(): Int {
            return self.lockedNFTCount
        }

        /// Depending on the number of locked NFTs, this may fail.
        ///
        access(all)
        view fun getIDs(): [UInt64] {
            return self.lockedNFTs.keys
        }

        /// Returns all the EVM IDs of the locked NFTs if the locked token implements CrossVMNFT.EVMNFT
        ///
        access(all)
        view fun getEVMIDs(): [UInt256] {
            return self.evmIDToFlowID.keys
        }

        /// Returns the Flow NFT ID associated with the EVM NFT ID if the locked token implements CrossVMNFT.EVMNFT
        ///
        access(all)
        view fun getCadenceID(from evmID: UInt256): UInt64? {
            if self.evmIDToFlowID[evmID] == nil && self.borrowNFT(UInt64(evmID)) != nil {
                return UInt64(evmID)
            }
            return self.evmIDToFlowID[evmID]
        }

        /// Returns a reference to the NFT if it is locked
        ///
        access(all)
        view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.lockedNFTs[id]
        }

        /// Returns a map of supported NFT types - at the moment Lockers only support the lockedNFTType defined by
        /// their contract
        ///
        access(all)
        view fun getSupportedNFTTypes(): {Type: Bool} {
            return {
                self.lockedType: self.isSupportedNFTType(type: self.lockedType)
            }
        }

        /// Returns true if the NFT type is supported
        ///
        access(all)
        view fun isSupportedNFTType(type: Type): Bool {
            return type == self.lockedType
        }

        /// Returns the NFT as a Resolver if it is locked
        ///
        access(all)
        view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            return self.borrowNFT(id)
        }

        /// Deposits the NFT into this locker, noting its EVM ID if it implements CrossVMNFT.EVMNFT
        ///
        access(all)
        fun deposit(token: @{NonFungibleToken.NFT}) {
            pre {
                self.borrowNFT(token.id) == nil: "NFT with this ID already exists in the Locker"
            }
            if let evmID = CrossVMNFT.getEVMID(from: &token as &{NonFungibleToken.NFT}) {
                self.evmIDToFlowID[evmID] = token.id
            }
            self.lockedNFTCount = self.lockedNFTCount + 1
            self.lockedNFTs[token.id] <-! token
        }

        /// Withdraws the NFT from this locker, removing it from the collection and returning it
        ///
        access(NonFungibleToken.Withdraw | NonFungibleToken.Owner)
        fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            // Should not happen, but prevent potential underflow
            assert(self.lockedNFTCount > 0, message: "No NFTs to withdraw")
            self.lockedNFTCount = self.lockedNFTCount - 1
            let token <- self.lockedNFTs.remove(key: withdrawID)!
            if let evmID = CrossVMNFT.getEVMID(from: &token as &{NonFungibleToken.NFT}) {
                self.evmIDToFlowID.remove(key: evmID)
            }
            return <- token
        }

        /// Creates an empty Collection - added here for NFT.Collection conformance
        ///
        access(all)
        fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- create Locker(lockedType: self.lockedType, erc721Address: self.erc721Address)
        }
    }
}
