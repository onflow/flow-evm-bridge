import "EVM"

/// Returns the hex encoded address of the COA in the given Flow address
///
access(all) fun main(flowAddress: Address): String? {
    if let address: EVM.EVMAddress = getAuthAccount<auth(BorrowValue) &Account>(flowAddress)
        .storage.borrow<&EVM.BridgedAccount>(from: /storage/evm)?.address() {
        let bytes: [UInt8] = []
        for byte in address.bytes {
            bytes.append(byte)
        }
        return String.encodeHex(bytes)
    }
    return nil
}
