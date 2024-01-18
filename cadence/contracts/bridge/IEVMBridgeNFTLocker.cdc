import "FlowToken"
import "NonFungibleToken"
import "ViewResolver"

import "EVM"

import "ICrossVM"

/// Defines an NFT Locker interface used to lock bridge Flow-native NFTs. Included so the contract can be borrowed by
/// the main bridge contract without statically declaring the contract due to dynamic deployments
/// An implementation of this contract will be templated to be named dynamically based on the locked NFT Type
///
access(all) contract interface IEVMBridgeNFTLocker : ICrossVM {

    /// Type of NFT locked in the contract
    access(all) let lockedNFTType: Type
    /// Pointer to the defining Flow-native contract
    access(all) let flowNFTContractAddress: Address
    /// Pointer to the Factory deployed Solidity contract address defining the bridged asset
    access(all) let evmNFTContractAddress: EVM.EVMAddress
    /// Resource which holds locked NFTs
    access(contract) let locker: @{Locker, NonFungibleToken.Collection}

    /// Asset bridged from Flow to EVM - satisfies both FT & NFT (always amount == 1.0)
    // TODO: Add evmContractAddress back once COA.address() is view
    // access(all) event BridgedToEVM(type: Type, id: UInt64, to: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress, flowNative: Bool)
    access(all) event BridgedToEVM(type: Type, id: UInt64, to: EVM.EVMAddress, flowNative: Bool)
    /// Asset bridged from EVM to Flow - satisfies both FT & NFT (always amount == 1.0)
    // TODO: Add caller and evmContractAddress back once COA.address() is view
    // access(all) event BridgedFromEVM(type: Type, id: UInt64, caller: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress, flowNative: Bool)
    access(all) event BridgedFromEVM(type: Type, id: UInt64, flowNative: Bool)

    /* --- Auxiliary entrypoints --- */

    access(all) fun bridgeToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault) {
        pre {
            emit BridgedToEVM(
                type: token.getType(),
                id: token.getID(),
                to: to,
                // evmContractAddress: self.getEVMContractAddress(),
                flowNative: true
            )
        }
    }

    access(all) fun bridgeFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @FlowToken.Vault
    ): @{NonFungibleToken.NFT} {
        post {
            emit BridgedFromEVM(
                type: result.getType(),
                id: result.getID(),
                // caller: caller.address(),
                // evmContractAddress: self.getEVMContractAddress(),
                flowNative: true
            )
        }
    }

    /* --- Getters --- */

    access(all) view fun getLockedNFTCount(): Int
    access(all) view fun borrowLockedNFT(id: UInt64): &{NonFungibleToken.NFT}?

    /* --- Locker interface --- */

    access(all) resource interface Locker : NonFungibleToken.Collection {
        access(all) view fun isLocked(id: UInt64): Bool
    }
}
