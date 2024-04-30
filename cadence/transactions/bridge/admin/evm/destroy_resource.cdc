import "Burner"

/// Destroys the resource at the given storage path.
///
transaction(resourceStoragePath: StoragePath) {
    
    let r: @AnyResource
    
    prepare(signer: auth(LoadValue) &Account) {
        self.r <- signer.storage.load<@AnyResource>(from: resourceStoragePath)
    }

    execute {
        destroy self.r
    }
}
