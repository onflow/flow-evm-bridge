import "FlowToken"
import "NonFungibleToken"
import "ViewResolver"

import "EVM"

import "CrossVMNFT"

/// Defines an NFT Locker interface used to lock bridged Flow-native NFTs. Included so the contract can be borrowed by
/// the main bridge contract without statically declaring the contract due to dynamic deployments
/// An implementation of this contract will be templated to be named dynamically based on the locked NFT Type
///
access(all) contract interface IEVMBridgeNFTEscrow {

    /****************
        Getters
    *****************/

    access(all)
    view fun isInitialized(forType: Type): Bool
    access(all)
    view fun borrowLockedNFT(type: Type, id: UInt64): &{NonFungibleToken.NFT}?
    access(all)
    view fun isLocked(type: Type, id: UInt64): Bool

    access(account)
    fun initializeEscrow(forType: Type, erc721Address: EVM.EVMAddress)
    access(account)
    fun lockNFT(_ nft: @{NonFungibleToken.NFT})
    access(account)
    fun unlockNFT(type: Type, id: UInt64): @{NonFungibleToken.NFT}
}
