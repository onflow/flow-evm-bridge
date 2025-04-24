import "FlowEVMBridgeConfig"

/// Returns the bridge-defined Type that was originally associated with the related EVM contract given some
/// externally defined contract. This would arise in the event an EVM-native project onboarded to the bridge via
/// permissionless onboarding & later registered their own Cadence NFT contract as associated with their ERV721 per
/// FLIP-318 mechanisms. If there is not a related bridge-defined Type registered with the bridge, `nil` is returned.
///
/// @param type: The cross-VM Cadence Type for which the caller is seeking the originally associated bridged Type
///
/// @return The bridge-defined asset Type originally associated with the updated cross-VM asset association if exists
///
access(all)
fun main(type: Type): Type? {
    return FlowEVMBridgeConfig.getLegacyTypeForCustomCrossVMType(type)
}
