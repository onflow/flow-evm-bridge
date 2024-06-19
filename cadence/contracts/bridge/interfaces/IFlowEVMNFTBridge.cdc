import "FungibleToken"
import "NonFungibleToken"

import "EVM"

import "FlowEVMBridgeConfig"
import "CrossVMNFT"

access(all) contract interface IFlowEVMNFTBridge {
    
    /*************
        Events
    **************/

    /// Broadcasts an NFT was bridged from Cadence to EVM
    access(all)
    event BridgedNFTToEVM(
        type: String,
        id: UInt64,
        uuid: UInt64,
        evmID: UInt256,
        to: String,
        evmContractAddress: String,
        bridgeAddress: Address
    )
    /// Broadcasts an NFT was bridged from EVM to Cadence
    access(all)
    event BridgedNFTFromEVM(
        type: String,
        id: UInt64,
        uuid: UInt64,
        evmID: UInt256,
        caller: String,
        evmContractAddress: String,
        bridgeAddress: Address
    )

    /**************
        Getters
    ***************/

    /// Returns the EVM address associated with the provided type
    ///
    access(all)
    view fun getAssociatedEVMAddress(with type: Type): EVM.EVMAddress?

    /// Returns the EVM address of the bridge coordinating COA
    ///
    access(all)
    view fun getBridgeCOAEVMAddress(): EVM.EVMAddress

    /********************************
        Public Bridge Entrypoints
    *********************************/

    /// Public entrypoint to bridge NFTs from Cadence to EVM.
    ///
    /// @param token: The NFT to be bridged
    /// @param to: The NFT recipient in FlowEVM
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun bridgeNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            emit BridgedNFTToEVM(
                type: token.getType().identifier,
                id: token.id,
                uuid: token.uuid,
                evmID: CrossVMNFT.getEVMID(from: &token as &{NonFungibleToken.NFT}) ?? UInt256(token.id),
                to: to.toString(),
                evmContractAddress: self.getAssociatedEVMAddress(with: token.getType())?.toString()
                    ?? panic("Could not find EVM Contract address associated with provided NFT"),
                bridgeAddress: self.account.address
            )
        }
    }

    /// Public entrypoint to bridge NFTs from EVM to Cadence
    ///
    /// @param owner: The EVM address of the NFT owner. Current ownership and successful transfer (via 
    ///     `protectedTransferCall`) is validated before the bridge request is executed.
    /// @param calldata: Caller-provided approve() call, enabling contract COA to operate on NFT in EVM contract
    /// @param id: The NFT ID to bridged
    /// @param evmContractAddress: Address of the EVM address defining the NFT being bridged - also call target
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    /// @param protectedTransferCall: A function that executes the transfer of the NFT from the named owner to the
    ///     bridge's COA. This function is expected to return a Result indicating the status of the transfer call.
    ///
    /// @returns The bridged NFT
    ///
    access(account)
    fun bridgeNFTFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        id: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (): EVM.Result
    ): @{NonFungibleToken.NFT} {
        post {
            emit BridgedNFTFromEVM(
                type: result.getType().identifier,
                id: result.id,
                uuid: result.uuid,
                evmID: id,
                caller: owner.toString(),
                evmContractAddress: self.getAssociatedEVMAddress(with: result.getType())?.toString()
                    ?? panic("Could not find EVM Contract address associated with provided NFT"),
                bridgeAddress: self.account.address
            )
        }
    }
}