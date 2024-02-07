import "FlowToken"
import "NonFungibleToken"
import "ViewResolver"

import "EVM"

import "ICrossVM"
import "CrossVMNFT"
import "IFlowEVMNFTBridge"

/// Defines an NFT Locker interface used to lock bridge Flow-native NFTs. Included so the contract can be borrowed by
/// the main bridge contract without statically declaring the contract due to dynamic deployments
/// An implementation of this contract will be templated to be named dynamically based on the locked NFT Type
///
access(all) contract interface IEVMBridgeNFTLocker : ICrossVM, IFlowEVMNFTBridge {

    /// Type of NFT locked in the contract
    access(all) let lockedNFTType: Type
    /// Pointer to the defining Flow-native contract
    access(all) let flowNFTContractAddress: Address
    /// Pointer to the Factory deployed Solidity contract address defining the bridged asset
    access(all) let evmNFTContractAddress: EVM.EVMAddress
    /// Resource which holds locked NFTs
    access(contract) let locker: @{Locker, NonFungibleToken.Collection}

    /****************
        Getters
    *****************/

    access(all) view fun getLockedNFTCount(): Int
    access(all) view fun borrowLockedNFT(id: UInt64): &{NonFungibleToken.NFT}?

    /*************************
        Locker interface
    **************************/

    access(all) resource interface Locker : CrossVMNFT.EVMNFTCollection, NonFungibleToken.Collection {
        access(all) view fun isLocked(id: UInt64): Bool
    }
}
