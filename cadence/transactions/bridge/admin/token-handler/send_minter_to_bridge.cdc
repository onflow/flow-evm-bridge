import "USDCFlow"

/// Sends the USDCFlow Minter to the bridge for use in the TokenHandler
///
/// @param bridgeAddress: The address of the bridge to send the minter to
///
/// NOTE: This transaction should be executed after the TokenHandler has been configured and minter type has been set.
/// As implemented in FlowEVMBridgeHandlers.CadenceNativeTokenHandler, a minter can only be configured once and must
/// be of the expected type when set.
///
transaction(bridgeAddress: Address) {
    prepare(signer: &Account) {
        USDCFlow.sendMinterToBridge(bridgeAddress)
    }
}
