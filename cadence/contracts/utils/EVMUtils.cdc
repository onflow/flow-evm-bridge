import "EVM"

/// Contract containing EVM-related utility methods
///
access(all) contract EVMUtils {
    /// Returns an EVMAddress as a hex string without a 0x prefix
    ///
    /// @param address: The EVMAddress to convert to a hex string
    ///
    /// @return The hex string representation of the EVMAddress without 0x prefix
    ///
    // TODO: Remove once EVMAddress.toString() is available
    access(all)
    view fun getEVMAddressAsHexString(address: EVM.EVMAddress): String {
        return String.encodeHex(address.bytes.toVariableSized())
    }

    /// Returns an EVMAddress as a hex string without a 0x prefix, truncating the string's last 20 bytes if exceeded
    ///
    /// @param address: The hex string to convert to an EVMAddress without the 0x prefix
    ///
    /// @return The EVMAddress representation of the hex string
    ///
    access(all)
    fun getEVMAddressFromHexString(address: String): EVM.EVMAddress? {
        pre {
            address.length == 40 || address.length == 42: "Invalid hex string length"
        }
        // Strip the 0x prefix if it exists
        var withoutPrefix = (address[1] == "x" ? address.slice(from: 2, upTo: address.length) : address).toLower()
        let bytes = withoutPrefix.decodeHex().toConstantSized<[UInt8;20]>()!
        return EVM.EVMAddress(bytes: bytes)
    }
}
