import "EVM"

import "FlowEVMBridgeAccessor"

/// This transaction is intended to be run once by the EVM contract account after FlowEVMBridgeAccessor.BridgeAccessor
/// has been configured in the bridge account and its Capability has been published to be claimed by the EVM account.
///
/// @param name: The name of the BridgeAccessor Capability to claim
/// @param provider: The address of the account that published the BridgeAccessor Capability
///
transaction(name: String, provider: Address) {

    let accessorCap: Capability<auth(EVM.Bridge) &FlowEVMBridgeAccessor.BridgeAccessor>
    let routerRef: auth(EVM.Bridge) &{EVM.BridgeRouter}

    prepare(signer: auth(BorrowValue, ClaimInboxCapability, SaveValue) &Account) {
        let routerStoragePath = /storage/evmBridgeRouter
        
        // Claim the BridgeAccessor Capability
        self.accessorCap = signer.inbox.claim<auth(EVM.Bridge) &FlowEVMBridgeAccessor.BridgeAccessor>(
                name,
                provider: provider
            ) ?? panic("BridgeAccessor Capability not found")

        // Ensure the Capability is valid and nothing is stored where the BridgeRouter should be stored
        assert(self.accessorCap.check() == true, message: "Invalid BridgeAccessor Capability")
        assert(
            signer.storage.type(at: routerStoragePath) == nil,
            message: "Collision where BridgeRouter will be stored"
        )

        let router <-self.accessorCap.borrow()!.createBridgeRouter()
        signer.storage.save(<-router, to: routerStoragePath)

        // Borrow the router from storage and set the BridgeAccessor Capability
        self.routerRef = signer.storage.borrow<auth(EVM.Bridge) &{EVM.BridgeRouter}>(from: routerStoragePath)
            ?? panic("BridgeRouter not found in storage")
    }

    execute {
        self.routerRef.setBridgeAccessor(self.accessorCap)
    }
}
