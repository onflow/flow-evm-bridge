/// Contains a resource interface for assets that can be bridged to other environments
///
access(all) contract CrossVMAsset {
    
    /// Enables retrieval of a resource's default bridge Flow address
    ///
    access(all) resource interface BridgeableAsset {
        /// Returns the address of the bridge contract host
        access(all) view fun getDefaultBridgeAddress(): Address
        /// Returns a reference to a contract as `&AnyStruct`. This enables the result to be cast as a bridging
        /// contract by the caller and avoids circular dependency in the implementing contract
        access(all) view fun borrowDefaultBridgeContract(): &AnyStruct
    }
}
