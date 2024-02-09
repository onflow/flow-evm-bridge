import "FungibleToken"
import "NonFungibleToken"
import "FlowToken"

import "EVM"

import "CrossVMNFT"

access(all) contract interface IFlowEVMNFTBridge {

    /* --- Contract address associations --- */
    //
    // Assuming a 1:1 relationship between bridge Cadence & Solidity contracts where the implementing bridge targets
    // a single EVM contract and a single Flow contract
    //
    /// The address of the EVM contract targetted by this bridge. Defines the NFT being bridged in Flow EVM
    access(all) let evmNFTContractAddress: EVM.EVMAddress
    /// The address of the Flow contract targetted by this bridge. Defines the NFT being bridged in Flow
    access(all) let flowNFTContractAddress: Address

    /* --- Interface Events --- */
    //
    /// Broadcasts an NFT was bridged from Flow to EVM
    access(all) event BridgedNFTToEVM(
        type: Type,
        id: UInt64,
        evmID: UInt256,
        to: EVM.EVMAddress,
        evmContractAddress: EVM.EVMAddress,
        bridgeAddress: Address
    )
    /// Broadcasts an NFT was bridged from EVM to Flow - caller commented until EVM.BridgedAccount.address() is view
    access(all) event BridgedNFTFromEVM(type: Type,
        id: UInt64,
        evmID: UInt256,
        // caller: EVM.EVMAddress,
        evmContractAddress: EVM.EVMAddress,
        bridgeAddress: Address
    )

    /// Returns the amount of fungible tokens required to bridge an NFT
    ///
    access(all) view fun getFeeAmount(): UFix64
    /// Returns the type of fungible tokens the bridge accepts for fees
    ///
    access(all) view fun getFeeVaultType(): Type

    /// Public entrypoint to bridge NFTs from Flow to EVM - cross-account bridging supported (e.g. straight to EOA)
    ///
    /// @param token: The NFT to be bridged
    /// @param to: The NFT recipient in FlowEVM
    /// @param tollFee: The fee paid for bridging
    ///
    access(all) fun bridgeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @{FungibleToken.Vault}) {
        pre {
            emit BridgedNFTToEVM(
                type: token.getType(),
                id: token.getID(),
                evmID: CrossVMNFT.getEVMID(from: &token) ?? UInt256(token.getID()),
                to: to,
                evmContractAddress: self.evmNFTContractAddress,
                bridgeAddress: self.account.address
            )
        }
    }

    /// Public entrypoint to bridge NFTs from EVM to Flow
    ///
    /// @param caller: The caller executing the bridge - must be passed to check EVM state pre- & post-call in scope
    /// @param calldata: Caller-provided approve() call, enabling contract COA to operate on NFT in EVM contract
    /// @param id: The NFT ID to bridged
    /// @param evmContractAddress: Address of the EVM address defining the NFT being bridged - also call target
    /// @param tollFee: The fee paid for bridging
    ///
    /// @returns The bridged NFT
    ///
    access(all) fun bridgeNFTFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @{FungibleToken.Vault}
    ): @{NonFungibleToken.NFT} {
        post {
            emit BridgedNFTFromEVM(
                type: result.getType(),
                id: result.getID(),
                evmID: id,
                // caller: caller.address(),
                evmContractAddress: self.evmNFTContractAddress,
                bridgeAddress: self.account.address
            )
        }
    }

}
