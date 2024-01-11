import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

import "EVM"

import "IEVMBridgeNFTLocker"
import "FlowEVMBridgeUtils"
import "FlowEVMBridge"

// TODO:
// - [ ] Consider case where NFT IDs are not unique - is this worth supporting?
// - [ ] Pull URI from NFT if display exists & pass on minting
//
access(all) contract CONTRACT_NAME : IEVMBridgeNFTLocker {
    /// Type of NFT locked in the contract
    access(all) let lockedNFTType: Type
    /// Pointer to the defining Flow-native contract
    access(all) let flowNFTContractAddress: Address
    /// Pointer to the Factory deployed Solidity contract address defining the bridged asset
    access(all) let evmNFTContractAddress: EVM.EVMAddress
    /// Resource which holds locked NFTs
    access(contract) let locker: @{IEVMBridgeNFTLocker.Locker}

    /* --- Auxiliary entrypoints --- */

    // TODO: Consider implementing ICrossEVMNFT.EVMBridgeableCollection in Locker and passing through to Locker
    //      as an example of a bridgeable collection
    access(all) fun bridgeToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault) {
        pre {
            token.getType() == self.lockedNFTType: "Invalid NFT type for this Locker"
            tollFee >= FlowEVMBridge.fee: "Insufficient bridging fee provided"
        }
        FlowEVMBridgeUtils.depositTollFee(<-tollFee)
        let id: UInt256 = token.id as UInt256

        let isFlowNative = FlowEVMBridgeUtils.isFlowNative(asset: &token)
        emit BridgedToEVM(
            type: token.getType(),
            amount: 1.0,
            to: to,
            evmContractAddress: self.evmNFTContractAddress,
            flowNative: true
        )

        self.locker.deposit(token: <-token)
        // TODO - pull URI from NFT if display exists & pass on minting
        self.call(
            signature: "safeMintTo(address,uint256,string)",
            targetEVMAddress: self.evmNFTContractAddress,
            args: [id, to, "MOCK_URI"],
            gasLimit: 60000,
            value: 0.0
        )

    }

    access(all) fun bridgeFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @FlowToken.Vault
    ): @{NonFungibleToken.NFT} {
        pre {
            tollFee >= FlowEVMBridge.fee: "Insufficient bridging fee provided"
            evmContractAddress == self.evmNFTContractAddress: "EVM contract address is not associated with this Locker"
        }
        let isNFT: Bool = FlowEVMBridgeUtils.isEVMNFT(evmContractAddress: evmContractAddress)
        let isToken: Bool = FlowEVMBridgeUtils.isEVMToken(evmContractAddress: evmContractAddress)
        assert(isNFT && !isToken, message: "Unsupported asset type")

        // Ensure caller is current NFT owner or approved
        let isAuthorized: Bool = FlowEVMBridgeUtils.isOwnerOrApproved(
            ofNFT: id,
            owner: caller.address(),
            evmContractAddress: evmContractAddress
        )
        assert(isAuthorized, message: "Caller is not the owner of or approved for requested NFT")

        // Execute provided approve call
        caller.call(
            to: evmContractAddress,
            data: calldata,
            gasLimit: 60000,
            value: EVM.Balance(flow: 0.0)
        )

        // Execute transfer of NFT to bridge COA address
        self.call(
            signature: "safeTransferFrom(address,address,uint256)",
            targetEVMAddress: evmContractAddress,
            args: [caller.address(), FlowEVMBridge.getBridgeCOAEVMAddress(), id],
            gasLimit: 60000,
            value: 0.0
        )

        let isBridgeOwned: Bool = FlowEVMBridgeUtils.isOwnerOrApproved(
            ofNFT: id,
            owner: FlowEVMBridge.getBridgeCOAEVMAddress(),
            evmContractAddress: evmContractAddress
        )
        assert(isBridgeOwned, message: "Bridge was not approved for requested NFT")

        let convertedID: UInt64 = FlowEVMBridgeUtils.uint256ToUInt64(value: id)
        return <- self.locker.withdraw(withdrawID: convertedID)
    }

    /* --- Getters --- */

    access(all) view fun getLockedNFTCount(): Int {
        return self.locker.getLength()
    }
    access(all) view fun borrowLockedNFT(id: UInt64): &{NonFungibleToken.NFT}? {
        return self.locker.borrowNFT(id)
    }

    /// Retrieves the corresponding EVM contract address, assuming a 1:1 relationship between VM implementations
    access(all) fun getEVMContractAddress(): EVM.EVMAddress {
        return self.evmNFTContractAddress
    }

    /* --- Locker --- */

    // TODO: Consider implementing ICrossEVMNFT.EVMBridgeableCollection interface
    access(all) resource Locker : IEVMBridgeNFTLocker.Locker {
        /// Count of locked NFTs as lockedNFTs.length may exceed computation limits
        access(self) var lockedNFTCount: Int
        /// Indexed on NFT UUID to prevent collisions
        access(self) let lockedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init() {
            self.lockedNFTCount = 0
            self.lockedNFTs <- {}
        }

        /* --- Getters --- */

        /// Returns the number of locked NFTs
        ///
        access(all) view fun getLength(): Int {
            return self.lockedNFTCount
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

        /// Returns true if the NFT is locked
        ///
        access(all) view fun isLocked(id: UInt64): Bool {
            return self.borrowNFT(id) != nil
        }

        /// Returns the NFT as a Resolver if it is locked
        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            return self.borrowNFT(id)
        }

        /// Depending on the number of locked NFTs, this may fail. See isLocked() as fallback to check if as specific
        /// NFT is locked
        ///
        access(all) view fun getIDs(): [UInt64] {
            return self.lockedNFTs.keys
        }

        /// No default storage path for this Locker as it's contract-owned - needed for Collection conformance
        access(all) view fun getDefaultStoragePath(): StoragePath? {
            return nil
        }

        /// No default public path for this Locker as it's contract-owned - needed for Collection conformance
        access(all) view fun getDefaultPublicPath(): PublicPath? {
            return nil
        }

        /// Deposits the NFT into this locker
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            pre {
                self.borrowNFT(token.id) == nil: "NFT with this ID already exists in the Locker"
            }
            self.lockedNFTCount = self.lockedNFTCount + 1
            self.lockedNFTs[token.id] <-! token
        }

        /// Withdraws the NFT from this locker
        access(NonFungibleToken.Withdrawable) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            // Should not happen, but prevent underflow
            assert(self.lockedNFTCount > 0, message: "No NFTs to withdraw")
            self.lockedNFTCount = self.lockedNFTCount - 1

            return <-self.lockedNFTs.remove(key: withdrawID)!
        }

    }

    /* --- Internal --- */

    access(self) fun call(
        signature: String,
        targetEVMAddress: EVM.EVMAddress,
        args: [AnyStruct],
        gasLimit: UInt64,
        value: UFix64
    ): [UInt8] {
        let methodID: [UInt8] = FlowEVMBridgeUtils.getFunctionSelector(signature: signature)
            ?? panic("Problem getting function selector for ".concat(signature))
        let calldata: [UInt8] = methodID.concat(EVM.encodeABI(args))
        let response = FlowEVMBridge.borrowCOA().call(
            to: targetEVMAddress,
            data: calldata,
            gasLimit: 60000,
            value: EVM.Balance(flow: value)
        )
        return response
    }

    init(lockedNFTType: Type, flowNFTContractAddress: Address, evmNFTContractAddress: EVM.EVMAddress) {
        pre {
            lockedNFTType.isSubtype(of: Type<@{NonFungibleToken.NFT}>()): "Locker must be initialized with a valid NFT type"
        }

        self.lockedNFTType = lockedNFTType
        self.flowNFTContractAddress = flowNFTContractAddress
        self.evmNFTContractAddress = evmNFTContractAddress

        self.locker <- create Locker()
    }
}
