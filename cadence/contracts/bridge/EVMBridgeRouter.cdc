import "FungibleToken"
import "NonFungibleToken"

import "EVM"

import "FlowEVMBridgeConfig"

/// This contract defines a mechanism for routing bridge requests from the EVM contract to the Flow-EVM bridge as well
/// as updating the designated bridge address
///
access(all)
contract EVMBridgeRouter {

    access(all)
    entitlement Admin
    
    /// Emitted in the event the bridge address is updated
    access(all)
    event BridgeCapabilityUpdated(type: Type, oldAddress: Address, newAddress: Address)
    
    /// BridgeAccessor implementation used by the EVM contract to route bridge calls between VMs
    ///
    access(all)
    resource Router : EVM.BridgeAccessor {
        /// The address hosting the BridgeAccessor resource which executes bridge requests
        access(self)
        var bridgeCapability: Capability<auth(EVM.Bridge) &{EVM.BridgeAccessor}>
        /// The address of the bridge contract
        access(self)
        var bridgeAddress: Address

        init(bridgeCapability: Capability<auth(EVM.Bridge) &{EVM.BridgeAccessor}>) {
            pre {
                bridgeCapability.check(): "Invalid Capability provided"
            }
            self.bridgeCapability = bridgeCapability
            self.bridgeAddress = bridgeCapability.borrow()!.owner!.address
        }
        
        /// Passes along the bridge request to the designated bridge address
        ///
        access(EVM.Bridge)
        fun depositNFT(nft: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, fee: @{FungibleToken.Vault}) {
            self.borrowBridgeAccessor().depositNFT(nft: <-nft, to: to, fee: <-fee)
        }

        /// Updates the designated bridge Capability
        ///
        access(Admin)
        fun updateBridgeCapability(to: Capability<auth(EVM.Bridge) &{EVM.BridgeAccessor}>) {
            pre {
                to.check(): "Invalid Capability provided"
            }
            let newAddress = to.borrow()!.owner!.address
            emit BridgeCapabilityUpdated(type: to.getType(), oldAddress: self.bridgeAddress, newAddress: newAddress)
            self.bridgeCapability = to
            self.bridgeAddress = newAddress
        }

        /// Retrieves a reference to the BridgeAccessor from the encapsulated Capability
        ///
        access(self)
        fun borrowBridgeAccessor(): auth(EVM.Bridge) &{EVM.BridgeAccessor} {
            return self.bridgeCapability.borrow() ?? panic("Could not borrow Bridge reference")
        }
    }

    init(bridgeAddress: Address) {
        let bridgeCapability = self.account.inbox.claim<auth(EVM.Bridge) &{EVM.BridgeAccessor}>(
                "EVMBridgeAccessor",
                provider: bridgeAddress
            ) ?? panic("No capability has been published for claiming")
        self.account.storage.save(<-create Router(bridgeCapability: bridgeCapability), to: /storage/evmBridgeRouter)
    }
}
