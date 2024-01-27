import NonFungibleToken from 0xf8d6e0586b0a20c7
import MetadataViews from 0xf8d6e0586b0a20c7
import ViewResolver from 0xf8d6e0586b0a20c7
import FlowToken from 0x0ae53cb6e3f42a79

import EVM from 0xf8d6e0586b0a20c7

import IEVMBridgeNFTLocker from 0xf8d6e0586b0a20c7
import FlowEVMBridgeConfig from 0xf8d6e0586b0a20c7
import FlowEVMBridgeUtils from 0xf8d6e0586b0a20c7
import FlowEVMBridge from 0xf8d6e0586b0a20c7

/// This is a contract template for a Locker which can be used to lock NFTs on Flow and mint them on EVM. It's served
/// by the FlowEVMBridgeTemplates contract with `CONTRACT_NAME` replaced with the name derived from the NFT type.
///
access(all) contract CONTRACT_NAME : IEVMBridgeNFTLocker {

    /// Type of NFT locked in the contract
    access(all) let lockedNFTType: Type
    /// Pointer to the defining Flow-native contract
    access(all) let flowNFTContractAddress: Address
    /// Pointer to the Factory deployed Solidity contract address defining the bridged asset
    access(all) let evmNFTContractAddress: EVM.EVMAddress
    /// Resource which holds locked NFTs
    access(contract) let locker: @{IEVMBridgeNFTLocker.Locker}

    /************************************
        Auxiliary Bridge Entrypoints
    *************************************/

    /// Bridges the NFT from Flow to EVM given the NFT is of the type handled by this locker, acting as a secondary
    /// bridge access point
    ///
    access(all) fun bridgeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault) {
        pre {
            token.getType() == self.lockedNFTType: "Invalid NFT type for this Locker"
            tollFee.getBalance() >= FlowEVMBridgeConfig.fee: "Insufficient bridging fee provided"
        }
        FlowEVMBridgeUtils.depositTollFee(<-tollFee)
        let id: UInt256 = UInt256(token.getID())

        let isFlowNative = FlowEVMBridgeUtils.isFlowNative(type: token.getType())

        self.locker.deposit(token: <-token)
        // TODO - pull URI from NFT if display exists & pass on minting
        FlowEVMBridgeUtils.call(
            signature: "safeMint(address,uint256,string)",
            targetEVMAddress: self.evmNFTContractAddress,
            args: [to, id, "MOCK_URI"],
            gasLimit: 15000000,
            value: 0.0
        )
    }

    /// Bridges the NFT from Flow to EVM given the NFT is of the type handled by this locker, acting as a secondary
    /// bridge access point
    ///
    access(all) fun bridgeNFTFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @FlowToken.Vault
    ): @{NonFungibleToken.NFT} {
        pre {
            tollFee.getBalance() >= FlowEVMBridgeConfig.fee: "Insufficient bridging fee provided"
            evmContractAddress.bytes == self.evmNFTContractAddress.bytes: "EVM contract address is not associated with this Locker"
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

        // Deposit fee
        FlowEVMBridgeUtils.depositTollFee(<-tollFee)

        // Execute provided approve call
        caller.call(
            to: evmContractAddress,
            data: calldata,
            gasLimit: 15000000,
            value: EVM.Balance(flow: 0.0)
        )

        // Burn the NFT
        FlowEVMBridgeUtils.call(
            signature: "burn(uint256)",
            targetEVMAddress: evmContractAddress,
            args: [id],
            gasLimit: 15000000,
            value: 0.0
        )

        // Ensure the NFT was burned
        let response: [UInt8] = FlowEVMBridgeUtils.borrowCOA().call(
                to: evmContractAddress,
                data: FlowEVMBridgeUtils.encodeABIWithSignature("exists(uint256)", [id]),
                gasLimit: 15000000,
                value: EVM.Balance(flow: 0.0)
            )
        let decoded: [AnyStruct] = EVM.decodeABI(types:[Type<Bool>()], data: response)
        let exists: Bool = decoded[0] as! Bool
        assert(exists == false, message: "NFT was not successfully burned")

        // Finally return the NFT to the caller
        let convertedID: UInt64 = FlowEVMBridgeUtils.uint256ToUInt64(value: id)
        return <- self.locker.withdraw(withdrawID: convertedID)
    }

    /**********************
            Getters
    ***********************/

    /// Retrieves the number of locked NFTs
    ///
    /// @returns Number of NFTs in the contract locker
    ///
    access(all) view fun getLockedNFTCount(): Int {
        return self.locker.getLength()
    }

    /// Retrieves a reference to the NFT with the given ID
    ///
    /// @param id ID of the NFT to retrieve
    ///
    /// @returns Reference to the NFT if it exists
    ///
    access(all) view fun borrowLockedNFT(id: UInt64): &{NonFungibleToken.NFT}? {
        return self.locker.borrowNFT(id)
    }

    /// Retrieves the corresponding EVM contract address, assuming a 1:1 relationship between VM implementations
    ///
    /// @returns EVM contract address defining bridge-managed NFT representing the locked NFT type
    ///
    access(all) fun getEVMContractAddress(): EVM.EVMAddress {
        return self.evmNFTContractAddress
    }

    /*********************
            Locker
    *********************/

    /// The resource managing the locking & unlocking of NFTs via this contract's interface
    ///
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
        ///
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
        ///
        access(all) view fun getDefaultStoragePath(): StoragePath? {
            return nil
        }

        /// No default public path for this Locker as it's contract-owned - needed for Collection conformance
        access(all) view fun getDefaultPublicPath(): PublicPath? {
            return nil
        }

        /// Deposits the NFT into this locker
        ///
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            pre {
                self.borrowNFT(token.getID()) == nil: "NFT with this ID already exists in the Locker"
            }
            self.lockedNFTCount = self.lockedNFTCount + 1
            self.lockedNFTs[token.getID()] <-! token
        }

        /// createEmptyCollection creates an empty Collection
        /// and returns it to the caller so that they can own NFTs
        // TODO: Will be removed with v2 updates
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- create Locker()
        }

        /// Withdraws the NFT from this locker
        ///
        access(NonFungibleToken.Withdrawable) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            // Should not happen, but prevent underflow
            assert(self.lockedNFTCount > 0, message: "No NFTs to withdraw")
            self.lockedNFTCount = self.lockedNFTCount - 1

            return <-self.lockedNFTs.remove(key: withdrawID)!
        }

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
