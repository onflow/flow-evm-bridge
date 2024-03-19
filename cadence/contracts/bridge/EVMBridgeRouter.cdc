import "NonFungibleToken"
import "FungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridgeConfig"
import "FlowEVMBridge"
import "FlowEVMBridgeNFTEscrow"

/// This contract defines a mechanism for routing bridge requests from the EVM contract to the Flow-EVM bridge as well
/// as updating the designated bridge address
///
access(all)
contract EVMBridgeRouter {
    
    /// BridgeAccessor implementation used by the EVM contract to route bridge calls between VMs
    ///
    access(all)
    resource Router : EVM.BridgeAccessor {

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
                    to: FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
                        ?? panic("No EVM address associated with type"),
                    data: EVM.encodeABIWithSignature(
                        "safeTransferFrom(address,address,uint256)",
                        [caller.address(), FlowEVMBridge.getBridgeCOAEVMAddress(), id]
                    ),
                    gasLimit: 15000000,
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
    }

    init() {
        self.account.storage.save(<-create Router(), to: /storage/evmBridgeRouter)
    }
}
