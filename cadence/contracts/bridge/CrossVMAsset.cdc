/// Contains a resource interface for assets that can be bridged to other environments
///
access(all) contract CrossVMAsset {
    
    /// Enables retrieval of a resource's default bridge Flow address
    ///
    access(all) resource interface BridgeableAsset {
        access(all) view fun getDefaultBridgeAddress(): Address
    }
}
