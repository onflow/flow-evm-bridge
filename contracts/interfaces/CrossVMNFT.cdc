import "EVM"

access(all) contract CrossVMNFT {

    access(all) resource interface Collection {
        access(all) fun bridge(id: UInt64, to: EVM.EVMAddress)
    }
}
