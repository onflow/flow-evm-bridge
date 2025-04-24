import "FlowEVMBridgeConfig"

/// Returns the bridge-defined Type that was originally associated with the related EVM contract given some
/// externally defined contract. This would arise in the event an EVM-native project onboarded to the bridge via
/// permissionless onboarding & later registered their own Cadence NFT contract as associated with their ERV721 per
/// FLIP-318 mechanisms. If there is not a related custom cross-VM Type registered with the bridge, `nil` is
/// returned.
///
/// @param type: The bridge-defined Cadence Type for which the caller is seeking the updated cross-VM asset Type
///
/// @return The externally-defined asset Type that now replaces the bridged type if one exists
///
access(all)
fun main(type: Type): Type? {
    return FlowEVMBridgeConfig.getUpdatedCustomCrossVMType(type)
}
