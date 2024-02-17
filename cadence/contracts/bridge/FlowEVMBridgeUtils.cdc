import "NonFungibleToken"
import "FungibleToken"
import "FlowToken"

import "EVM"
import "FlowEVMBridgeConfig"

/// This contract serves as a source of utility methods leveraged by FlowEVMBridge contracts
//
access(all) contract FlowEVMBridgeUtils {

    /// Address of the bridge factory Solidity contract
    access(all) let bridgeFactoryEVMAddress: EVM.EVMAddress
    /// Delimeter used to derive contract names
    access(self) let contractNameDelimiter: String
    /// Mapping containing contract name prefixes
    access(self) let contractNamePrefixes: {Type: {String: String}}

    /// Returns an EVMAddress as a hex string without a 0x prefix
    ///
    /// @param: address The EVMAddress to convert to a hex string
    ///
    /// @return The hex string representation of the EVMAddress without 0x prefix
    ///
    // TODO: Remove once EVMAddress.toString() is available
    access(all) fun getEVMAddressAsHexString(address: EVM.EVMAddress): String {
        let addressBytes: [UInt8] = []
        for byte in address.bytes {
            addressBytes.append(byte)
        }
        return String.encodeHex(addressBytes)
    }

    /// Returns an EVMAddress as a hex string without a 0x prefix, truncating the string's last 20 bytes if exceeded
    ///
    /// @param: address The hex string to convert to an EVMAddress
    ///
    /// @return The EVMAddress representation of the hex string
    ///
    access(all) fun getEVMAddressFromHexString(address: String): EVM.EVMAddress? {
        var addressBytes: [UInt8] = address.decodeHex()
        if addressBytes.length > 20 {
            addressBytes = addressBytes.slice(from: addressBytes.length - 20, upTo: addressBytes.length)
        }
        return EVM.EVMAddress(bytes: [
            addressBytes[0], addressBytes[1], addressBytes[2], addressBytes[3],
            addressBytes[4], addressBytes[5], addressBytes[6], addressBytes[7],
            addressBytes[8], addressBytes[9], addressBytes[10], addressBytes[11],
            addressBytes[12], addressBytes[13], addressBytes[14], addressBytes[15],
            addressBytes[16], addressBytes[17], addressBytes[18], addressBytes[19]
        ])
    }

    /// Identifies if an asset is Flow- or EVM-native, defined by whether a bridge contract defines it or not
    ///
    /// @param: type The Type of the asset to check
    ///
    /// @return True if the asset is Flow-native, false if it is EVM-native
    ///
    access(all) fun isFlowNative(type: Type): Bool {
        let definingAddress: Address = self.getContractAddress(fromType: type)
            ?? panic("Could not construct address from type identifier: ".concat(type.identifier))
        return definingAddress != self.account.address
    }

    /// Identifies if an asset is Flow- or EVM-native, defined by whether a bridge-owned contract defines it or not
    ///
    /// @param: type The Type of the asset to check
    ///
    access(all) fun isEVMNative(evmContractAddress: EVM.EVMAddress): Bool {
        return self.isEVMContractBridgeOwned(evmContractAddress: evmContractAddress) == false
    }

    /// Determines if the given EVM contract address was deployed by the bridge by querying the factory contract
    ///
    /// @param: evmContractAddress The EVM contract address to check
    ///
    access(all) fun isEVMContractBridgeOwned(evmContractAddress: EVM.EVMAddress): Bool {
        // Ask the bridge factory if the given contract address was deployed by the bridge
        let response: [UInt8] = self.call(
                signature: "isFactoryDeployed(address)",
                targetEVMAddress: self.bridgeFactoryEVMAddress,
                args: [evmContractAddress],
                gasLimit: 60000,
                value: 0.0
            )
        let decodedResponse: [AnyStruct] = EVM.decodeABI(types: [Type<Bool>()], data: response)
        let decodedBool: Bool = decodedResponse[0] as! Bool
        return decodedBool
    }

    /// Identifies if an asset is ERC721
    ///
    access(all) fun isEVMNFT(evmContractAddress: EVM.EVMAddress): Bool {
        let response: [UInt8] = self.call(
            signature: "isERC721(address)",
            targetEVMAddress: self.bridgeFactoryEVMAddress,
            args: [evmContractAddress],
            gasLimit: 100000,
            value: 0.0
        )
        let decodedResponse: [AnyStruct] = EVM.decodeABI(types: [Type<Bool>()], data: response)
        return decodedResponse[0] as! Bool
    }
    /// Identifies if an asset is ERC20
    ///
    access(all) fun isEVMToken(evmContractAddress: EVM.EVMAddress): Bool {
        // TODO: We will need to figure out how to identify ERC20s without ERC165 support
        return false
    }
    /// Returns whether the contract address is either an ERC721 or ERC20 exclusively
    ///
    access(all) fun isValidEVMAsset(evmContractAddress: EVM.EVMAddress): Bool {
        let isEVMNFT: Bool = FlowEVMBridgeUtils.isEVMNFT(evmContractAddress: evmContractAddress)
        let isEVMToken: Bool = FlowEVMBridgeUtils.isEVMToken(evmContractAddress: evmContractAddress)
        return (isEVMNFT && !isEVMToken) || (!isEVMNFT && isEVMToken)
    }
    /// Returns whether the given type is either an NFT or FT exclusively
    ///
    access(all) view fun isValidFlowAsset(type: Type): Bool {
        let isFlowNFT: Bool = type.isSubtype(of: Type<@{NonFungibleToken.NFT}>())
        let isFlowToken: Bool = type.isSubtype(of: Type<@{FungibleToken.Vault}>())
        return (isFlowNFT && !isFlowToken) || (!isFlowNFT && isFlowToken)
    }

    /// Retrieves the NFT/FT name from the given EVM contract address - applies for both ERC20 & ERC721
    ///
    access(all) fun getName(evmContractAddress: EVM.EVMAddress): String {
        let response: [UInt8] = self.call(
            signature: "name()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: 60000,
            value: 0.0
        )
        let decodedResponse = EVM.decodeABI(types: [Type<String>()], data: response) as! [AnyStruct]
        return decodedResponse[0] as! String
    }

    /// Retrieves the NFT/FT symbol from the given EVM contract address - applies for both ERC20 & ERC721
    access(all) fun getSymbol(evmContractAddress: EVM.EVMAddress): String {
        let response: [UInt8] = self.call(
            signature: "symbol()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: 60000,
            value: 0.0
        )
        let decodedResponse = EVM.decodeABI(types: [Type<String>()], data: response) as! [AnyStruct]
        return decodedResponse[0] as! String
    }

    /// Retrieves the number of decimals for a given ERC20 contract address
    access(all) fun getTokenDecimals(evmContractAddress: EVM.EVMAddress): UInt8 {
        let response: [UInt8] = self.call(
                signature: "decimals()",
                targetEVMAddress: evmContractAddress,
                args: [],
                gasLimit: 60000,
                value: 0.0
            )
        let decodedResponse = EVM.decodeABI(types: [Type<UInt8>()], data: response) as! [AnyStruct]
        return decodedResponse[0] as! UInt8
    }

    /// Determines if the provided owner address is either the owner or approved for the NFT in the ERC721 contract
    access(all) fun isOwnerOrApproved(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        return self.isOwner(ofNFT: ofNFT, owner: owner, evmContractAddress: evmContractAddress) ||
            self.isApproved(ofNFT: ofNFT, owner: owner, evmContractAddress: evmContractAddress)
    }

    access(all) fun isOwner(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let calldata: [UInt8] = FlowEVMBridgeUtils.encodeABIWithSignature("ownerOf(uint256)", [ofNFT])
        let ownerResponse: [UInt8] = self.borrowCOA().call(
                to: evmContractAddress,
                data: calldata,
                gasLimit: 12000000,
                value: EVM.Balance(flow: 0.0)
            )
        let decodedOwnerResponse: [AnyStruct] = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: ownerResponse)
        if decodedOwnerResponse.length == 1 {
            let actualOwner: EVM.EVMAddress = decodedOwnerResponse[0] as! EVM.EVMAddress
            return actualOwner.bytes == owner.bytes
        }
        return false
    }

    access(all) fun isApproved(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let approvedResponse: [UInt8] = self.call(
            signature: "getApproved(uint256)",
            targetEVMAddress: evmContractAddress,
            args: [ofNFT],
            gasLimit: 12000000,
            value: 0.0
        )
        let decodedApprovedResponse: [AnyStruct] = EVM.decodeABI(
                types: [Type<EVM.EVMAddress>()],
                data: approvedResponse
            )
        if decodedApprovedResponse.length == 1 {
            let actualApproved: EVM.EVMAddress = decodedApprovedResponse[0] as! EVM.EVMAddress
            actualApproved.bytes == owner.bytes
        }
        return false
    }

    /// Determines if the owner has sufficient funds to bridge the given amount at the ERC20 contract address
    access(all) fun hasSufficientBalance(amount: UFix64, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let response: [UInt8] = self.call(
            signature: "balanceOf(address)",
            targetEVMAddress: evmContractAddress,
            args: [owner],
            gasLimit: 60000,
            value: 0.0
        )
        let decodedResponse: [UInt256] = EVM.decodeABI(types: [Type<UInt256>()], data: response) as! [UInt256]
        let tokenDecimals: UInt8 = self.getTokenDecimals(evmContractAddress: evmContractAddress)
        return self.uint256ToUFix64(value: decodedResponse[0], decimals: tokenDecimals) >= amount
    }

    /// Derives the Cadence contract name for a given Type of the form
    /// (EVMVMNFTLocker|EVMVMTokenLocker)_<0xCONTRACT_ADDRESS><CONTRACT_NAME><RESOURCE_NAME>
    access(all) view fun deriveLockerContractName(fromType: Type): String? {
        // Bridge-defined assets are not locked
        if self.getContractAddress(fromType: fromType) == self.account.address {
            return nil
        }

        if let splitIdentifier: [String] = self.splitObjectIdentifier(identifier: fromType.identifier) {
            let sourceContractAddress: Address = Address.fromString("0x".concat(splitIdentifier[1]))!
            let sourceContractName: String = splitIdentifier[2]
            let resourceName: String = splitIdentifier[3]

            var prefix: String? = nil
            if fromType.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) &&
                !fromType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
                prefix = self.contractNamePrefixes[Type<@{NonFungibleToken.NFT}>()]!["locker"]!

            } else if fromType.isSubtype(of: Type<@{FungibleToken.Vault}>()) &&
                !fromType.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) {
                prefix = self.contractNamePrefixes[Type<@{FungibleToken.Vault}>()]!["locker"]!
            }

            if prefix != nil {
                return prefix!.concat(self.contractNameDelimiter)
                    .concat(sourceContractAddress.toString()).concat(self.contractNameDelimiter)
                    .concat(sourceContractName).concat(self.contractNameDelimiter)
                    .concat(resourceName)
            }
        }
        return nil
    }
    /// Derives the Cadence contract name for a given EVM NFT of the form
    /// EVMVMBridgedNFT_<0xCONTRACT_ADDRESS>
    access(all) fun deriveBridgedNFTContractName(from evmContract: EVM.EVMAddress): String {
        // Concatenate the prefix & t
        return self.contractNamePrefixes[Type<@{NonFungibleToken.NFT}>()]!["bridged"]!
            .concat(self.contractNameDelimiter)
            .concat("0x".concat(self.getEVMAddressAsHexString(address: evmContract)))
    }
    /// Derives the Cadence contract name for a given EVM fungible token of the form
    /// EVMVMBridgedToken_<0xCONTRACT_ADDRESS>
    access(all) fun deriveBridgedTokenContractName(from evmContract: EVM.EVMAddress): String {
        return self.contractNamePrefixes[Type<@{FungibleToken.Vault}>()]!["bridged"]!
            .concat(self.contractNameDelimiter)
            .concat("0x".concat(self.getEVMAddressAsHexString(address: evmContract)))
    }

    /* --- Math Utils --- */

    /// Raises the base to the power of the exponent
    access(all) view fun pow(base: UInt256, exponent: UInt8): UInt256 {
        if exponent == 0 {
            return 1
        }

        var r = base
        var exp: UInt8 = 1
        while exp < exponent {
            r = r * base
            exp = exp + 1
        }

        return r
    }
    /// Converts a UInt256 to a UFix64
    access(all) view fun uint256ToUFix64(value: UInt256, decimals: UInt8): UFix64 {
        let scaleFactor: UInt256 = self.pow(base: 10, exponent: decimals)
        let scaledValue: UInt256 = value / scaleFactor

        assert(scaledValue > UInt256(UInt64.max), message: "Value too large to fit into UFix64")

        return UFix64(scaledValue)
    }
    /// Converts a UFix64 to a UInt256
    access(all) view fun ufix64ToUInt256(value: UFix64, decimals: UInt8): UInt256 {
        let integerPart: UInt64 = UInt64(value)
        var r = UInt256(integerPart)

        var multiplier: UInt256 = self.pow(base:10, exponent: decimals)
        return r * multiplier
    }
    /// Returns the value as a UInt64 if it fits, otherwise panics
    access(all) view fun uint256ToUInt64(value: UInt256): UInt64 {
        return value <= UInt256(UInt64.max) ? UInt64(value) : panic("Value too large to fit into UInt64")
    }

    /* --- Type Identifier Utils --- */

    access(all) view fun getContractAddress(fromType: Type): Address? {
        // Split identifier of format A.<CONTRACT_ADDRESS>.<CONTRACT_NAME>.<RESOURCE_NAME>
        if let identifierSplit: [String] = self.splitObjectIdentifier(identifier: fromType.identifier) {
            return Address.fromString("0x".concat(identifierSplit[1]))
        }
        return nil
    }

    access(all) fun getContractName(fromType: Type): String? {
        // Split identifier of format A.<CONTRACT_ADDRESS>.<CONTRACT_NAME>.<RESOURCE_NAME>
        if let identifierSplit: [String] = self.splitObjectIdentifier(identifier: fromType.identifier) {
            return identifierSplit[2]
        }
        return nil
    }

    access(all) view fun splitObjectIdentifier(identifier: String): [String]? {
        let identifierSplit: [String] = identifier.split(separator: ".")
        return identifierSplit.length != 4 ? nil : identifierSplit
    }

    access(all) view fun buildCompositeType(address: Address, contractName: String, resourceName: String): Type? {
        let addressStr = address.toString()
        let subtract0x = addressStr.slice(from: 2, upTo: addressStr.length)
        let identifier = "A".concat(".").concat(subtract0x).concat(".").concat(contractName).concat(".").concat(resourceName)
        return CompositeType(identifier)
    }

    /* --- ABI Utils --- */
    // TODO: Remove once available in EVM contract
    access(all) fun encodeABIWithSignature(
        _ signature: String,
        _ values: [AnyStruct]
    ): [UInt8] {
        let methodID = HashAlgorithm.KECCAK_256.hash(
            signature.utf8
        ).slice(from: 0, upTo: 4)
        let arguments = EVM.encodeABI(values)

        return methodID.concat(arguments)
    }

    access(all) fun decodeABIWithSignature(
        _ signature: String,
        types: [Type],
        data: [UInt8]
    ): [AnyStruct] {
        let methodID = HashAlgorithm.KECCAK_256.hash(
            signature.utf8
        ).slice(from: 0, upTo: 4)

        for byte in methodID {
            if byte != data.removeFirst() {
                panic("signature mismatch")
            }
        }

        return EVM.decodeABI(types: types, data: data)
    }

    /* --- Bridge-Access Only Utils --- */
    // TODO: Embed these methods into an Admin resource

    /// Deposits fees to the bridge account's FlowToken Vault - helps fund asset storage
    access(account) fun depositTollFee(_ tollFee: @{FungibleToken.Vault}) {
        pre {
            tollFee.getType() == Type<@FlowToken.Vault>(): "Fee paid in invalid token type"
        }
        let vault = self.account.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken.Vault reference")
        vault.deposit(from: <-tollFee)
    }

    /// Enables other bridge contracts to orchestrate bridge operations from contract-owned COA
    access(account) fun borrowCOA(): &EVM.BridgedAccount {
        return self.account.storage.borrow<&EVM.BridgedAccount>(from: FlowEVMBridgeConfig.coaStoragePath)
            ?? panic("Could not borrow COA reference")
    }

    /// Shared helper simplifying calls using the bridge account's COA
    access(account) fun call(
        signature: String,
        targetEVMAddress: EVM.EVMAddress,
        args: [AnyStruct],
        gasLimit: UInt64,
        value: UFix64
    ): [UInt8] {
        let calldata: [UInt8] = self.encodeABIWithSignature(signature, args)
        let response: [UInt8] = self.borrowCOA().call(
            to: targetEVMAddress,
            data: calldata,
            gasLimit: gasLimit,
            value: EVM.Balance(flow: value)
        )
        return response
    }

    init(bridgeFactoryEVMAddress: String) {
        self.contractNameDelimiter = "_"
        self.contractNamePrefixes = {
            Type<@{NonFungibleToken.NFT}>(): {
                "locker": "EVMVMBridgeNFTLocker",
                "bridged": "EVMVMBridgedNFT"
            },
            Type<@{FungibleToken.Vault}>(): {
                "locker": "EVMVMBridgeTokenLocker",
                "bridged": "EVMVMBridgedToken"
            }
        }
        let bridgeFactoryEVMAddressBytes: [UInt8] = bridgeFactoryEVMAddress.decodeHex()
        self.bridgeFactoryEVMAddress = EVM.EVMAddress(bytes: [
            bridgeFactoryEVMAddressBytes[0], bridgeFactoryEVMAddressBytes[1], bridgeFactoryEVMAddressBytes[2], bridgeFactoryEVMAddressBytes[3],
            bridgeFactoryEVMAddressBytes[4], bridgeFactoryEVMAddressBytes[5], bridgeFactoryEVMAddressBytes[6], bridgeFactoryEVMAddressBytes[7],
            bridgeFactoryEVMAddressBytes[8], bridgeFactoryEVMAddressBytes[9], bridgeFactoryEVMAddressBytes[10], bridgeFactoryEVMAddressBytes[11],
            bridgeFactoryEVMAddressBytes[12], bridgeFactoryEVMAddressBytes[13], bridgeFactoryEVMAddressBytes[14], bridgeFactoryEVMAddressBytes[15],
            bridgeFactoryEVMAddressBytes[16], bridgeFactoryEVMAddressBytes[17], bridgeFactoryEVMAddressBytes[18], bridgeFactoryEVMAddressBytes[19]
        ])
    }
}
