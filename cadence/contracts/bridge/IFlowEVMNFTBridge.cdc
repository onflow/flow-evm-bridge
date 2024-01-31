import "FungibleToken"
import "NonFungibleToken"
import "FlowToken"

import "EVM"

access(all) contract interface IFlowEVMNFTBridge {

    /// Public entrypoint to bridge NFTs from Flow to EVM - cross-account bridging supported (e.g. straight to EOA)
    ///
    /// @param token: The NFT to be bridged
    /// @param to: The NFT recipient in FlowEVM
    /// @param tollFee: The fee paid for bridging
    ///
    access(all) fun bridgeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @{FungibleToken.Vault})

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
    ): @{NonFungibleToken.NFT}

}
