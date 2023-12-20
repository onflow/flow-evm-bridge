import "EVM"

access(all) contract CrossVMFT {

    access(all) resource interface Vault {
        access(all) fun bridge(amount: UFix64, to: EVM.EVMAddress)
    }
}
