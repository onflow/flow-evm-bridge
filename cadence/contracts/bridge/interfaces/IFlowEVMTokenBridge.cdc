import "FungibleToken"
import "NonFungibleToken"

import "EVM"

import "EVMUtils"

access(all) contract interface IFlowEVMTokenBridge {
    
    /*************
        Events
    **************/

    /// Broadcasts fungible tokens were bridged from Cadence to EVM
    access(all)
    event BridgedTokensToEVM(
        type: Type,
        amount: UFix64,
        to: String,
        evmContractAddress: String,
        bridgeAddress: Address
    )
    /// Broadcasts fungible tokens were bridged from EVM to Cadence
    access(all)
    event BridgedTokensFromEVM(
        type: Type,
        amount: UInt256,
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

    /// Public entrypoint to bridge fungible tokens from Cadence to EVM.
    ///
    /// @param token: The token Vault to be bridged
    /// @param to: The token recipient in EVM
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun bridgeTokensToEVM(
        vault: @{FungibleToken.Vault},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            emit BridgedTokensToEVM(
                type: vault.getType(),
                amount: vault.balance,
                to: EVMUtils.getEVMAddressAsHexString(address: to),
                evmContractAddress: EVMUtils.getEVMAddressAsHexString(
                    address: self.getAssociatedEVMAddress(with: vault.getType())
                        ?? panic("Could not find EVM Contract address associated with provided NFT")
                ), bridgeAddress: self.account.address
            )
        }
    }

    /// Public entrypoint to bridge fungible tokens from EVM to Cadence
    ///
    /// @param owner: The EVM address of the token owner. Current ownership and successful transfer (via 
    ///     `protectedTransferCall`) is validated before the bridge request is executed.
    /// @param type: The Cadence Type of the fungible token to be bridged. If EVM-native, this would be the Cadence
    ///     Type associated with the EVM contract on the Flow side at onboarding.
    /// @param amount: The amount of tokens to bridge from EVM to Cadence
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    /// @param protectedTransferCall: A function that executes the transfer of the NFT from the named owner to the
    ///     bridge's COA. This function is expected to return a Result indicating the status of the transfer call.
    ///
    /// @returns The bridged NFT
    ///
    access(account)
    fun bridgeTokensFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        amount: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (): EVM.Result
    ): @{FungibleToken.Vault} {
        post {
            emit BridgedTokensFromEVM(
                type: result.getType(),
                amount: amount,
                caller: EVMUtils.getEVMAddressAsHexString(address: owner),
                evmContractAddress: EVMUtils.getEVMAddressAsHexString(
                    address: self.getAssociatedEVMAddress(with: result.getType())
                        ?? panic("Could not find EVM Contract address associated with provided Vault")
                ), bridgeAddress: self.account.address
            )
        }
    }
}