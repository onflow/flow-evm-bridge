import "EVM"

/// Converts EVM address bytes into to a hex string
///
access(all) fun main(bytes: [UInt8]): String? {
    let constBytes = bytes.toConstantSized<[UInt8; 20]>()
        ?? panic("Problem converting provided EVMAddress compatible byte array - check byte array contains 20 bytes")
    return EVM.EVMAddress(
        bytes: constBytes
    )
}
