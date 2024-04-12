import "FlowEVMBridgeConfig"

/// Sets the storage rate charged per base storage unit paid for escrowed asset storage.
///
/// @param newFee: The cost per base unit of storage
///
/// @emits FlowEVMBridgeConfig.StorageRateUpdated(old: FlowEVMBridgeConfig.baseFee, new: newFee)
///
transaction(newFee: UFix64) {
    prepare(signer: auth(BorrowValue) &Account) {
        signer.storage.borrow<&FlowEVMBridgeConfig.Admin>(from: FlowEVMBridgeConfig.adminStoragePath)
            ?.updateStorageRate(newFee)
            ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
    }
}
