/// This contract defines a simple interface which can be implemented by any resource to prevent it from being
/// onboarded to the Flow-EVM bridge
///
/// NOTE: This is suggested only for cases where your asset (NFT/FT) incorporates non-standard logic that would
///      break your project if not handles properly
///      e.g. assets are reclaimed after a certain period of time, NFTs share IDs, etc.
///
access(all)
contract interface IBridgePermissions {
    /// Contract-level method enabling implementing contracts to identify whether they allow bridging for their
    /// project's assets. Implementers may consider adding a hook which would later enable an update to this value
    /// should either the project be updated or the bridge be updated to handle the asset's non-standard logic which 
    /// would otherwise prevent them from supporting VM bridging at the outset.
    ///
    access(all)
    view fun allowsBridging(): Bool {
        return false
    }
}
