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
        let bytes = address.bytes
        // Iterating & appending to an array is not allowed in a `view` method and this method must be `view` for
        // certain use cases in the bridge contracts - namely for emitting values in pre- & post-conditions
        let addressBytes: [UInt8] = [
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15],
            bytes[16], bytes[17], bytes[18], bytes[19]
        ]
        return String.encodeHex(addressBytes)
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
        // Remove the 0x prefix if it exists
        let sanitized = (address[1] == "x" ? address.split(separator: "x")[1] : address).toLower()
        if sanitized.length != 40 {
            return nil
        }
        // Decode the hex string
        var addressBytes: [UInt8] = address.decodeHex()
        if addressBytes.length != 20 {
            return nil
        }
        // Return the EVM address from the decoded hex string
        return EVM.EVMAddress(bytes: [
            addressBytes[0], addressBytes[1], addressBytes[2], addressBytes[3],
            addressBytes[4], addressBytes[5], addressBytes[6], addressBytes[7],
            addressBytes[8], addressBytes[9], addressBytes[10], addressBytes[11],
            addressBytes[12], addressBytes[13], addressBytes[14], addressBytes[15],
            addressBytes[16], addressBytes[17], addressBytes[18], addressBytes[19]
        ])
    }
}
