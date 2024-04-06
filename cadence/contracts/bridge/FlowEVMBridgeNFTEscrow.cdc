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
    access(all) view fun isInitialized(forType: Type): Bool {
        return self.borrowLocker(forType: forType) != nil
    }

    /// Returns whether an NFT with the given ID is locked
    ///
    /// @param id ID of the NFT to check
    ///
    /// @returns True if the NFT is locked, false otherwise
    ///
    access(all) view fun isLocked(type: Type, id: UInt64): Bool {
        return self.borrowLockedNFT(type: type, id: id) != nil
    }

    /// Retrieves the locked NFT's Cadence ID as defined in the NFT standard's NFT.id value if it is locked
    ///
    /// @param type: Type of the locked NFT
    /// @param evmID: EVM ID of the locked NFT
    ///
    /// @returns Cadence ID of the locked NFT if it exists
    ///
    access(all) view fun getLockedCadenceID(type: Type, evmID: UInt256): UInt64? {
        return self.borrowLocker(forType: type)?.getCadenceID(from: evmID) ?? nil
    }

    /// Returns the EVM NFT ID associated with the Cadence NFT ID. The goal is to retrieve the ERC721 ID value
    /// corresponding to the Cadence NFT.
    /// As far as the bridge is concerned, a bridge-deployed ERC721 assigns IDs based on NFT.id value at the time of
    /// bridging unless it implements the CrossVMNFT.EVMNFT in such case .evmID is used.
    /// Following this pattern, if locked, the NFT is checked for EVMNFT conformance returning .evmID,
    /// otherwise the NFT's ID is returned as a UInt256 as this is how the bridge would handle minting in the
    /// corresponding ERC721 contract.
    ///
    /// @param type: Type of the locked NFT
    /// @param cadenceID: Cadence ID of the locked NFT
    ///
    /// @returns EVM ID of the locked NFT if it exists
    ///
    access(all) view fun getLockedEVMID(type: Type, cadenceID: UInt64): UInt256? {
        return self.borrowLocker(forType: type)?.getEVMID(from: cadenceID) ?? nil
    }

    /// Resolves the requested view type for the given NFT type if it is locked and supports the requested view type
    ///
    /// @param nftType: Type of the locked NFT
    /// @param viewType: Type of the view to resolve
    /// @param id: ID of the locked NFT
    ///
    /// @returns The resolved view as AnyStruct if the NFT is locked and the view is supported, otherwise returns nil
    ///
    access(all) fun resolveLockedNFTView(nftType: Type, id: UInt256, viewType: Type): AnyStruct? {
        if let locker = self.borrowLocker(forType: nftType) {
            if let cadenceID = locker.getCadenceID(from: id) {
                return locker.borrowViewResolver(id: cadenceID)?.resolveView(viewType) ?? nil
            }
        }
        return nil
    }

    /**********************
        Bridge Methods
    ***********************/

    /// Initializes the Locker for the given NFT type if it hasn't been initialized yet
    ///
    access(account) fun initializeEscrow(forType: Type, name: String, symbol: String, erc721Address: EVM.EVMAddress) {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: forType)
            ?? panic("Problem deriving locker path")
        if self.account.storage.type(at: lockerPath) != nil {
            return
        }

        let locker <- create Locker(name: name, symbol: symbol, lockedType: forType, erc721Address: erc721Address)
        self.account.storage.save(<-locker, to: lockerPath)
    }

    /// Locks the NFT in escrow, returning the amount of storage used by the locker after storing
    ///
    access(account) fun lockNFT(_ nft: @{NonFungibleToken.NFT}): UInt64 {
        let locker = self.borrowLocker(forType: nft.getType())
            ?? panic("Problem deriving locker path")

        let preStorageSnapshot = self.account.storage.used
        locker.deposit(token: <-nft)
        let postStorageSnapshot = self.account.storage.used

        return postStorageSnapshot - preStorageSnapshot
    }

    /// Unlocks the NFT of the given type and ID, reverting if it isn't in escrow
    ///
    access(account) fun unlockNFT(type: Type, id: UInt64): @{NonFungibleToken.NFT} {
        let locker = self.borrowLocker(forType: type)
            ?? panic("Problem deriving locker path")
        return <- locker.withdraw(withdrawID: id)
    }


    /// Retrieves a reference to the NFT of the given type and ID if it is locked, otherwise returns nil
    ///
    access(account) view fun borrowLockedNFT(type: Type, id: UInt64): &{NonFungibleToken.NFT}? {
        if let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: type) {
            return self.account.storage.borrow<&Locker>(from: lockerPath)?.borrowNFT(id) ?? nil
        }
        return nil
    }

    /// Retrieves an entitled locker for the given type or nil if it doesn't exist
    ///
    access(self) view fun borrowLocker(forType: Type): auth(NonFungibleToken.Withdraw) &Locker? {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: forType)
            ?? panic("Problem deriving locker path")
        return self.account.storage.borrow<auth(NonFungibleToken.Withdraw) &Locker>(from: lockerPath)
    }

    /*********************
            Locker
    *********************/

    /// The resource managing the locking & unlocking of NFTs via this contract's interface
    ///
    access(all) resource Locker : CrossVMNFT.EVMNFTCollection {
        /// Corresponding name assigned in the tokens' corresponding ERC20 contract
        access(all) let name: String
        /// Corresponding symbol assigned in the tokens' corresponding ERC20 contract
        access(all) let symbol: String
        /// Corresponding ERC721 address for the locked NFTs
        access(all) let erc721Address: EVM.EVMAddress
        /// The type of NFTs this Locker escrows
        access(all) let lockedType: Type
        /// Count of locked NFTs as lockedNFTs.length may exceed computation limits
        access(self) var lockedNFTCount: Int
        /// Indexed on NFT UUID to prevent collisions
        access(self) let lockedNFTs: @{UInt64: {NonFungibleToken.NFT}}
        /// Maps EVM NFT ID to Flow NFT ID, covering cross-VM project NFTs
        access(self) let evmIDToFlowID: {UInt256: UInt64}

        init(name: String, symbol: String, lockedType: Type, erc721Address: EVM.EVMAddress) {
            self.name = name
            self.symbol = symbol
            self.lockedType = lockedType
            self.erc721Address = erc721Address
            self.lockedNFTCount = 0
            self.lockedNFTs <- {}
            self.evmIDToFlowID = {}
        }

        access(all)
        view fun getName(): String {
            return self.name
        }

        access(all)
        view fun getSymbol(): String {
            return self.symbol
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

        /// Returns the EVM NFT ID associated with the Cadence NFT ID. The goal is to retrieve the ERC721 ID value.
        /// As far as the bridge is concerned, an ERC721 defined by the bridge is the NFT's ID at the time of bridging
        /// or the value of the NFT.evmID if it implements the CrossVMNFT.EVMNFT interface when bridged.
        /// Following this pattern, if locked, the NFT is checked for EVMNFT conformance returning .evmID if so,
        /// otherwise the NFT's ID is returned as a UInt256 since that's how the bridge would handle minting in the
        /// corresponding ERC721 contract.
        ///
        access(all)
        view fun getEVMID(from cadenceID: UInt64): UInt256? {
            if let nft = self.borrowNFT(cadenceID) {
                if let evmNFT = CrossVMNFT.getEVMID(from: nft) {
                    return evmNFT
                }
                return UInt256(nft.id)
            }
            return nil
        }

        access(all) fun contractURI(): String? {
            return nil
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
            return <- create Locker(
                name: self.name,
                symbol: self.symbol,
                lockedType: self.lockedType,
                erc721Address: self.erc721Address
            )
        }
    }
}
