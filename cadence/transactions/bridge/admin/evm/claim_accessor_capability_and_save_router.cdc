import "EVM"

import "FlowEVMBridgeAccessor"

/// This transaction is intended to be run by the EVM contract account after FlowEVMBridgeAccessor.BridgeAccessor has
/// been configured in the bridge account and its Capability has been published to be claimed by the EVM account. If a
/// BridgeRouter implementation already exists from a previous bridge integration, it will be destroyed and replaced.
///
/// NOTE: The replacement of a BridgeRouter resource is an artifact of the iterative process on PreviewNet and should be
/// removed once an interface and integration pattern is solidified. If a new BridgeAccessor Capability must be set to
/// integrate the EVM contract with another bridge implementation, it should be set using the existing BridgeRouter
/// defined by a neutral party contract, not one related to bridge-specific deployments.
///
/// @param name: The name of the BridgeAccessor Capability to claim
/// @param provider: The address of the account that published the BridgeAccessor Capability
///
transaction(name: String, provider: Address) {

    let accessorCap: Capability<auth(EVM.Bridge) &FlowEVMBridgeAccessor.BridgeAccessor>
    let routerRef: auth(EVM.Bridge) &EVM.BridgeRouter

    prepare(signer: auth(ClaimInboxCapability, Storage) &Account) {
        let routerStoragePath = /storage/evmBridgeRouter
        
        // Claim the BridgeAccessor Capability
        self.accessorCap = signer.inbox.claim<auth(EVM.Bridge) &FlowEVMBridgeAccessor.BridgeAccessor>(
                name,
                provider: provider
            ) ?? panic("BridgeAccessor Capability not found")

        // Ensure the Capability is valid and nothing is stored where the BridgeRouter should be stored
        assert(self.accessorCap.check() == true, message: "Invalid BridgeAccessor Capability")

        if signer.storage.type(at: routerStoragePath) == nil {
            EVM.initBridgeRouter()
        }

        // Borrow the router from storage and set the BridgeAccessor Capability
        self.routerRef = signer.storage.borrow<auth(EVM.Bridge) &EVM.BridgeRouter>(from: routerStoragePath)
            ?? panic("BridgeRouter not found in storage")
    }

    execute {
        self.routerRef.setBridgeAccessor(self.accessorCap)
    }
}
