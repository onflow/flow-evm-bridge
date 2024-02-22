import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "FlowToken"

import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"
import "CrossVMNFT"

/// This escrow contract handles the custody of assets that are bridged from Flow to EVM and retrieval of escrowed
/// assets when they are bridged back to Flow.
///
access(all) contract FlowEVMBridgeNFTEscrow : IEVMBridgeNFTEscrow {

    /**********************
            Getters
    ***********************/

    /// Returns whether the Locker has been initialized for the given NFT type
    ///
    access(all) view fun isInitialized(forType: Type): Bool {
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
    access(all) view fun borrowLockedNFT(type: Type, id: UInt64): &{NonFungibleToken.NFT}? {
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
    access(all) view fun isLocked(type: Type, id: UInt64): Bool {
        return self.borrowLockedNFT(type: type, id: id) != nil
    }

    /**********************
            Getters
    ***********************/

    access(account)
    fun initializeEscrow(forType: Type) {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: nft.getType())
            ?? panic("Problem deriving locker path")
        if self.account.storage.type(at: lockerPath) != nil {
            return
        }
        let locker <- create Locker(lockedType: forType)
        self.account.storage.save(<-locker, to: lockerPath)
    }

    access(account)
    fun lockNFT(_ nft: @{NonFungibleToken.NFT}) {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: nft.getType())
            ?? panic("Problem deriving locker path")
        let locker = self.account.storage.borrow<&Locker>(from: lockerPath)
            ?? panic("Locker doesn't exist")
        locker.deposit(token: <-nft)
    }

    access(account)
    fun unlockNFT(type: Type, id: UInt64): @{NonFungibleToken.NFT} {
        let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: type)
            ?? panic("Problem deriving locker path")
        let locker = self.account.storage.borrow<auth(NonFungibleToken.Withdrawable) &Locker>(from: lockerPath)
            ?? panic("Locker doesn't exist")
        return <- locker.withdraw(withdrawID: id)
    }

    /* ----- BEGIN REMOVE ----- */
    //
    // /// Bridges the NFT from Flow to EVM given the NFT is of the type handled by this locker, acting as a secondary
    // /// bridge access point
    // ///
    // access(all) fun bridgeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @{FungibleToken.Vault}) {
    //     pre {
    //         token.getType() == self.lockedNFTType: "Invalid NFT type for this Locker"
    //         FlowEVMBridgeUtils.validateFee(&tollFee, onboarding: false): "Invalid fee paid"
    //     }
    //     FlowEVMBridgeUtils.depositTollFee(<-tollFee)
    //     let id: UInt64 = token.getID()
    //     var convertedID: UInt256 = CrossVMNFT.getEVMID(from: &token) ?? UInt256(token.getID())

    //     var uri: String = ""
    //     if let display = token.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display? {
    //         uri = display.thumbnail.uri()
    //     }
    //     self.locker.deposit(token: <-token)
    //     FlowEVMBridgeUtils.call(
    //         signature: "safeMint(address,uint256,string)",
    //         targetEVMAddress: self.evmNFTContractAddress,
    //         args: [to, convertedID, uri],
    //         gasLimit: 15000000,
    //         value: 0.0
    //     )
    // }

    // /// Bridges the NFT from Flow to EVM given the NFT is of the type handled by this locker, acting as a secondary
    // /// bridge access point
    // ///
    // access(all) fun bridgeNFTFromEVM(
    //     caller: &EVM.BridgedAccount,
    //     calldata: [UInt8],
    //     id: UInt256,
    //     evmContractAddress: EVM.EVMAddress,
    //     tollFee: @{FungibleToken.Vault}
    // ): @{NonFungibleToken.NFT} {
    //     pre {
    //         FlowEVMBridgeUtils.validateFee(&tollFee, onboarding: false): "Invalid fee paid"
    //         evmContractAddress.bytes == self.evmNFTContractAddress.bytes: "EVM contract address is not associated with this Locker"
    //     }
    //     // Ensure caller is current NFT owner or approved
    //     let isAuthorized: Bool = FlowEVMBridgeUtils.isOwnerOrApproved(
    //         ofNFT: id,
    //         owner: caller.address(),
    //         evmContractAddress: evmContractAddress
    //     )
    //     assert(isAuthorized, message: "Caller is not the owner of or approved for requested NFT")

    //     // Deposit fee
    //     FlowEVMBridgeUtils.depositTollFee(<-tollFee)

    //     // Execute provided approve call
    //     caller.call(
    //         to: evmContractAddress,
    //         data: calldata,
    //         gasLimit: 15000000,
    //         value: EVM.Balance(flow: 0.0)
    //     )

    //     // Burn the NFT
    //     FlowEVMBridgeUtils.call(
    //         signature: "burn(uint256)",
    //         targetEVMAddress: evmContractAddress,
    //         args: [id],
    //         gasLimit: 15000000,
    //         value: 0.0
    //     )

    //     // Ensure the NFT was burned
    //     let response: [UInt8] = FlowEVMBridgeUtils.borrowCOA().call(
    //             to: evmContractAddress,
    //             data: FlowEVMBridgeUtils.encodeABIWithSignature("exists(uint256)", [id]),
    //             gasLimit: 15000000,
    //             value: EVM.Balance(flow: 0.0)
    //         )
    //     let decoded: [AnyStruct] = EVM.decodeABI(types:[Type<Bool>()], data: response)
    //     assert(decoded.length == 1, message: "Invalid response length")
    //     let exists: Bool = decoded[0] as! Bool
    //     assert(exists == false, message: "NFT was not successfully burned")

    //     // Cover the case where Cadence NFT ID is not the same as EVM NFT ID
    //     var convertedID: UInt64? = nil
    //     if let flowID = self.locker.getFlowID(from: id) {
    //         convertedID = flowID
    //     } else {
    //         convertedID = FlowEVMBridgeUtils.uint256ToUInt64(value: id)
    //     }
    //     assert(convertedID != nil, message: "NFT ID conversion failed")

    //     // Finally return the NFT to the caller
    //     return <- self.locker.withdraw(withdrawID: convertedID!)
    // }
    //
    /* ----- END REMOVE ----- */

    /*********************
            Locker
    *********************/

    /// The resource managing the locking & unlocking of NFTs via this contract's interface
    ///
    access(all) resource Locker : CrossVMNFT.EVMNFTCollection, NonFungibleToken.Collection {
        access(all) let lockedType: Type
        /// Count of locked NFTs as lockedNFTs.length may exceed computation limits
        access(self) var lockedNFTCount: Int
        /// Indexed on NFT UUID to prevent collisions
        access(self) let lockedNFTs: @{UInt64: {NonFungibleToken.NFT}}
        /// Maps EVM NFT ID to Flow NFT ID, covering cross-VM project NFTs
        access(self) let evmIDToFlowID: {UInt256: UInt64}

        init(lockedType: Type) {
            self.lockedType = lockedType
            self.lockedNFTCount = 0
            self.lockedNFTs <- {}
            self.evmIDToFlowID = {}
        }

        /// Returns the number of locked NFTs
        ///
        access(all) view fun getLength(): Int {
            return self.lockedNFTCount
        }

        /// Depending on the number of locked NFTs, this may fail.
        ///
        access(all) view fun getIDs(): [UInt64] {
            return self.lockedNFTs.keys
        }

        /// Returns all the EVM IDs of the locked NFTs if the locked token implements CrossVMNFT.EVMNFT
        ///
        access(all) view fun getEVMIDs(): [UInt256] {
            return self.evmIDToFlowID.keys
        }

        /// Returns the Flow NFT ID associated with the EVM NFT ID if the locked token implements CrossVMNFT.EVMNFT
        ///
        access(all) view fun getFlowID(from evmID: UInt256): UInt64? {
            return self.evmIDToFlowID[evmID]
        }

        /// Returns a reference to the NFT if it is locked
        ///
        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.lockedNFTs[id]
        }

        /// Returns a map of supported NFT types - at the moment Lockers only support the lockedNFTType defined by
        /// their contract
        ///
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return {
                CONTRACT_NAME.lockedNFTType: self.isSupportedNFTType(type: CONTRACT_NAME.lockedNFTType)
            }
        }

        /// Returns true if the NFT type is supported
        ///
        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == CONTRACT_NAME.lockedNFTType
        }

        /// Returns the NFT as a Resolver if it is locked
        ///
        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            return self.borrowNFT(id)
        }

        /// Deposits the NFT into this locker, noting its EVM ID if it implements CrossVMNFT.EVMNFT
        ///
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            pre {
                self.borrowNFT(token.getID()) == nil: "NFT with this ID already exists in the Locker"
            }
            if let evmID = CrossVMNFT.getEVMID(from: &token) {
                self.evmIDToFlowID[evmID] = token.getID()
            }
            self.lockedNFTCount = self.lockedNFTCount + 1
            self.lockedNFTs[token.getID()] <-! token
        }

        /// Withdraws the NFT from this locker, removing it from the collection and returning it
        ///
        access(NonFungibleToken.Withdrawable) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            // Should not happen, but prevent underflow
            assert(self.lockedNFTCount > 0, message: "No NFTs to withdraw")
            self.lockedNFTCount = self.lockedNFTCount - 1
            let token <- self.lockedNFTs.remove(key: withdrawID)!
            if let evmID = CrossVMNFT.getEVMID(from: &token) {
                self.evmIDToFlowID.remove(key: evmID)
            }
            return <- token
        }

        /// No default storage path for this Locker as it's contract-owned - added for NFT.Collection conformance
        ///
        access(all) view fun getDefaultStoragePath(): StoragePath? {
            return nil
        }

        /// No default public path for this Locker as it's contract-owned - added for NFT.Collection conformance
        ///
        access(all) view fun getDefaultPublicPath(): PublicPath? {
            return nil
        }

        /// Creates an empty Collection - added here for NFT.Collection conformance
        ///
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- create Locker(lockedType): self.lockedType)
        }
    }
}
