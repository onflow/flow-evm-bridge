import "EVM"
import "FlowEVMBridgeConfig"

/// Returns the project-defined EVM contract address has been registered as a replacement for the originally bridge-
/// defined asset EVM contract. This would arise in the event an Cadence-native project onboarded to the bridge via
/// permissionless onboarding & later registered their own EVM contract as associated with their Cadence NFT per
/// FLIP-318 mechanisms. If there is not a related custom cross-VM EVM contract registered with the bridge, `nil` is
/// returned.
///
/// @param evmAddress: The bridge-defined EVM contract for which the caller is seeking the updated cross-VM EVM contract
///     
/// @return The externally-defined EVM contract that now replaces the bridged EVM contract if one exists
///
access(all)
fun main(evmAddress: String): EVM.EVMAddress? {
    return FlowEVMBridgeConfig.getUpdatedCustomCrossVMEVMAddressForLegacyEVMAddress(
        EVM.addressFromString(evmAddress)
    )
}
