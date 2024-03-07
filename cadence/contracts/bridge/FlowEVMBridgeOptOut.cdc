/// This contract defines a simple interface which can be implemented by any resource to prevent it from being
/// onboarded to the Flow-EVM bridge
///
access(all) contract FlowEVMBridgeOptOut {
    /// Implementing this interface in your resource will prevent it from being onboarded to the Flow-EVM bridge
    /// NOTE: This is suggested only for cases where your asset (NFT/FT) incorporates non-standard logic that would
    ///      break your project if not handles properly
    ///      e.g. assets are reclaimed after a certain period of time, NFTs share IDs, etc.
    access(all) resource interface Asset {}
}
