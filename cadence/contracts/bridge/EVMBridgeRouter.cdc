import "FungibleToken"
import "NonFungibleToken"

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
    resource Router : EVM.BridgeAccessor, EVM.EscrowAccessor {
        access(all) let bridgeAddress: Address
        /// Passes along the bridge request to dedicated bridge contract, returning any surplus fee
        ///
        access(EVM.Bridge)
        fun depositNFT(nft: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, fee: @FlowToken.Vault): @FlowToken.Vault {
            return <-FlowEVMBridge.bridgeNFTToEVM(nft: <-nft, to: to, tollfee: <-fee)
        }

        /// Passes along the bridge request to the dedicated bridge contract, returning the bridged NFT
        ///
        access(EVM.Bridge)
        fun withdrawNFT(
            caller: auth(EVM.Call) &EVM.CadenceOwnedAccount,
            type: Type,
            id: UInt256,
            fee: @FlowToken.Vault
        ): @{NonFungibleToken.NFT} {
            return <-FlowEVMBridge.bridgeNFTFromEVM(caller: caller, type: type, id: id, tollfee: <-fee)
        }


        access(EVM.Bridge)
        fun borrowLockedNFT(owner: auth(EVM.Validate) &EVM.CadenceOwnedAccount, type: Type, id: UInt256): &{NonFungibleToken.NFT}? {
            return FlowEVMBridgeNFTEscrow.borrowLockedNFT(owner: owner, type: type, id: id)
        }
    }

    init() {
        self.account.storage.save(<-create Router(), to: /storage/evmBridgeRouter)
    }
}
