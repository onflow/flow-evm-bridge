import "EVM"

import "FlowEVMBridgeAccessor"

/// This transaction is intended to be run once by the EVM contract account after FlowEVMBridgeAccessor.BridgeAccessor
/// has been configured in the bridge account and its Capability has been published to be claimed by the EVM account.
///
/// @param name: The name of the BridgeAccessor Capability to claim
/// @param provider: The address of the account that published the BridgeAccessor Capability
///
transaction(name: String, provider: Address) {

    prepare(signer: auth(Inbox, SaveValue) &Account) {
        // Claim the BridgeAccessor Capability
        let accessorCap = signer.inbox.claim<auth(EVM.Bridge) &FlowEVMBridgeAccessor.BridgeAccessor>(name, provider: provider)
            ?? panic("BridgeAccessor Capability not found")

        // Ensure the Capability is valid
        assert(accessorCap.check() == true, message: "Invalid BridgeAccessor Capability")

        // Create a Router to store the Capability and set the BridgeAccessor Capability in the Router
        let router <- accessorCap.borrow()!.createBridgeRouter()
        router.setBridgeAccessorCap(accessorCap)

        // Save the Router in storage
        signer.storage.save(<-router, to: /storage/evmBridgeRouter)
    }
}
