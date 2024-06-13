import "EVM"

/// Converts EVM address bytes into to a hex string
///
access(all) fun main(bytes: [UInt8]): String? {
    return EVM.EVMAddress(bytes: bytes.toConstantSized<[UInt8; 20]>())
}
