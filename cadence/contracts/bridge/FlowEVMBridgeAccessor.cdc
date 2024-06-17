import "NonFungibleToken"
import "FungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridge"

/// This contract defines a mechanism for routing bridge requests from the EVM contract to the Flow-EVM bridge contract
///
access(all)
contract FlowEVMBridgeAccessor {

    access(all) let StoragePath: StoragePath
    
    /// BridgeAccessor implementation used by the EVM contract to route bridge calls from COA resources
    ///
    access(all)
    resource BridgeAccessor : EVM.BridgeAccessor {

        /// Passes along the bridge request to dedicated bridge contract
        ///
        /// @param nft: The NFT to be bridged to EVM
        /// @param to: The address of the EVM account to receive the bridged NFT
        /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
        ///
        access(EVM.Bridge)
        fun depositNFT(
            nft: @{NonFungibleToken.NFT},
            to: EVM.EVMAddress,
            feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
        ) {
            FlowEVMBridge.bridgeNFTToEVM(token: <-nft, to: to, feeProvider: feeProvider)
        }

        /// Passes along the bridge request to the dedicated bridge contract, returning the bridged NFT
        ///
        /// @param caller: A reference to the COA which currently owns the NFT in EVM
        /// @param type: The Cadence type of the NFT to be bridged from EVM
        /// @param id: The ID of the NFT to be bridged from EVM
        /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
        ///
        /// @return The bridged NFT
        ///
        access(EVM.Bridge)
        fun withdrawNFT(
            caller: auth(EVM.Call) &EVM.CadenceOwnedAccount,
            type: Type,
            id: UInt256,
            feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
        ): @{NonFungibleToken.NFT} {
            // Define a callback function, enabling the bridge to act on the ephemeral COA reference in scope
            var executed = false
            fun callback(): EVM.Result {
                pre {
                    !executed: "Callback can only be executed once"
                }
                post {
                    executed: "Callback must be executed"
                }
                executed = true
                return caller.call(
                    to: FlowEVMBridge.getAssociatedEVMAddress(with: type)
                        ?? panic("No EVM address associated with type"),
                    data: EVM.encodeABIWithSignature(
                        "safeTransferFrom(address,address,uint256)",
                        [caller.address(), FlowEVMBridge.getBridgeCOAEVMAddress(), id]
                    ),
                    gasLimit: FlowEVMBridgeConfig.gasLimit,
                    value: EVM.Balance(attoflow: 0)
                )
            }
            // Execute the bridge request
            return <- FlowEVMBridge.bridgeNFTFromEVM(
                owner: caller.address(),
                type: type,
                id: id,
                feeProvider: feeProvider,
                protectedTransferCall: callback
            )
        }

        /// Passes along the bridge request to dedicated bridge contract
        ///
        /// @param vault: The fungible token vault to be bridged to EVM
        /// @param to: The address of the EVM account to receive the bridged tokens
        /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
        ///
        access(EVM.Bridge)
        fun depositTokens(
            vault: @{FungibleToken.Vault},
            to: EVM.EVMAddress,
            feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
        ) {
            FlowEVMBridge.bridgeTokensToEVM(vault: <-vault, to: to, feeProvider: feeProvider)
        }

        /// Passes along the bridge request to the dedicated bridge contract, returning the bridged NFT
        ///
        /// @param caller: A reference to the COA which currently owns the tokens in EVM
        /// @param type: The Cadence type of the fungible token vault to be bridged from EVM
        /// @param amount: The amount of tokens to be bridged
        /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
        ///
        /// @return The bridged NFT
        ///
        access(EVM.Bridge)
        fun withdrawTokens(
            caller: auth(EVM.Call) &EVM.CadenceOwnedAccount,
            type: Type,
            amount: UInt256,
            feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
        ): @{FungibleToken.Vault} {
            // Define a callback function, enabling the bridge to act on the ephemeral COA reference in scope
            var executed = false
            fun callback(): EVM.Result {
                pre {
                    !executed: "Callback can only be executed once"
                }
                post {
                    executed: "Callback must be executed"
                }
                executed = true
                return caller.call(
                    to: FlowEVMBridge.getAssociatedEVMAddress(with: type)
                        ?? panic("No EVM address associated with type"),
                    data: EVM.encodeABIWithSignature(
                        "transfer(address,uint256)",
                        [FlowEVMBridge.getBridgeCOAEVMAddress(), amount]
                    ),
                    gasLimit: FlowEVMBridgeConfig.gasLimit,
                    value: EVM.Balance(attoflow: 0)
                )
            }
            // Execute the bridge request
            return <- FlowEVMBridge.bridgeTokensFromEVM(
                owner: caller.address(),
                type: type,
                amount: amount,
                feeProvider: feeProvider,
                protectedTransferCall: callback
            )
        }

        /// Returns a BridgeRouter resource so a Capability on this BridgeAccessor can be stored in the BridgeRouter
        ///
        access(EVM.Bridge) fun createBridgeRouter(): @BridgeRouter {
            return <-create BridgeRouter()
        }
    }

    /// BridgeRouter implementation used by the EVM contract to capture a BridgeAccessor Capability and route bridge
    /// calls from COA resources to the FlowEVMBridge contract
    ///
    access(all) resource BridgeRouter : EVM.BridgeRouter {
        /// Capability to the BridgeAccessor resource, initialized to nil
        access(self) var bridgeAccessorCap: Capability<auth(EVM.Bridge) &{EVM.BridgeAccessor}>?

        init() {
            self.bridgeAccessorCap = nil
        }

        /// Returns an EVM.Bridge entitled reference to the underlying BridgeAccessor resource
        ///
        access(EVM.Bridge) view fun borrowBridgeAccessor(): auth(EVM.Bridge) &{EVM.BridgeAccessor} {
            let cap = self.bridgeAccessorCap ?? panic("BridgeAccessor Capabaility is not yet set")
            return cap.borrow() ?? panic("Problem retrieving BridgeAccessor reference")
        }

        /// Sets the BridgeAccessor Capability in the BridgeRouter
        access(EVM.Bridge) fun setBridgeAccessor(_ accessorCap: Capability<auth(EVM.Bridge) &{EVM.BridgeAccessor}>) {
            self.bridgeAccessorCap = accessorCap
        }
    }

    init(publishToEVMAccount: Address) {
        self.StoragePath = /storage/flowEVMBridgeAccessor
        self.account.storage.save(
            <-create BridgeAccessor(),
            to: self.StoragePath
        )
        let cap = self.account.capabilities.storage.issue<auth(EVM.Bridge) &BridgeAccessor>(self.StoragePath)
        self.account.inbox.publish(cap, name: "FlowEVMBridgeAccessor", recipient: publishToEVMAccount)
    }
}
