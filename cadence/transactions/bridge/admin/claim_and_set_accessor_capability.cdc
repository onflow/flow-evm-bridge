import "EVM"

import "FlowEVMBridgeAccessor"

/// This transaction is intended to be run by the EVM contract account after FlowEVMBridgeAccessor.BridgeAccessor in the
/// event the BridgeAccessor Capability needs to be reset within the store BridgeRouter. Within this transacion, the
/// prepare block assumes a BridgeRouter is already stored at /storage/evmBridgeRouter.
///
/// @param name: The name of the BridgeAccessor Capability to claim
/// @param provider: The address of the account that published the BridgeAccessor Capability
///
transaction(name: String, provider: Address) {

    let accessorCap: Capability<auth(EVM.Bridge) &FlowEVMBridgeAccessor.BridgeAccessor>
    let router: auth(EVM.Bridge) &{EVM.BridgeRouter}

    prepare(signer: auth(BorrowValue, ClaimInboxCapability, SaveValue) &Account) {
        // Claim the BridgeAccessor Capability
        self.accessorCap = signer.inbox.claim<auth(EVM.Bridge) &FlowEVMBridgeAccessor.BridgeAccessor>(
                name,
                provider: provider
            ) ?? panic("BridgeAccessor Capability not found")

        // Ensure the Capability is valid
        assert(self.accessorCap.check() == true, message: "Invalid BridgeAccessor Capability")

        // Borrow the router from storage and set the BridgeAccessor Capability
        self.router = signer.storage.borrow<auth(EVM.Bridge) &{EVM.BridgeRouter}>(from: /storage/evmBridgeRouter)
            ?? panic("BridgeRouter not found in storage")
    }

    execute {
        self.router.setBridgeAccessor(self.accessorCap)
    }
}
