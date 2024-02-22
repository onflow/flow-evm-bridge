import "FungibleToken"
import "NonFungibleToken"

import "EVM"

import "FlowEVMBridgeConfig"

/// This contract defines a mechanism for routing bridge requests from the EVM contract to the Flow-EVM bridge as well
/// as updating the designated bridge address
///
access(all) contract EVMBridgeRouter {

    access(all) entitlement Admin
    
    /// Emitted in the event the bridge address is updated
    access(all) event BridgeAddressUpdated(old: Address, new: Address)
    
    /// BridgeAccessor implementation used by the EVM contract to route bridge calls between VMs
    ///
    access(all) resource Router : EVM.BridgeAccessor {
        /// The address hosting the BridgeAccessor resource which executes bridge requests
        access(all) var bridgeAddress: Address

        init(_ bridgeAddress: Address) {
            self.bridgeAddress = bridgeAddress
        }
        
        /// Passes along the bridge request to the designated bridge address
        ///
        access(contract) fun depositNFT(nft: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, fee: @{FungibleToken.Vault}) {
            let bridgeAccessor = getAccount(self.bridgeAddress).capabilities.borrow<&{EVM.BridgeAccessor}>(
                    FlowEVMBridgeConfig.bridgeAccessorPublicPath
                ) ?? panic("Could not borrow Bridge reference")
            bridgeAccessor.depositNFT(nft: <-nft, to: to, fee: <-fee)
        }

        /// Updates the designated bridge address
        ///
        access(Admin) fun updateBridgeAddress(to: Address) {
            emit BridgeAddressUpdated(old: self.bridgeAddress, new: to)
            self.bridgeAddress = to
        }
    }

    init(bridgeAddress: Address) {
        self.account.storage.save(<-create Router(bridgeAddress), to: /storage/evmBridgeRouter)
    }
}
