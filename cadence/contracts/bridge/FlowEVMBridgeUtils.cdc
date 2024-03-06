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
    access(self) let delimiter: String
    /// Mapping containing contract name prefixes
    access(self) let contractNamePrefixes: {Type: {String: String}}

    /// Returns an EVMAddress as a hex string without a 0x prefix
    ///
    /// @param: address The EVMAddress to convert to a hex string
    ///
    /// @return The hex string representation of the EVMAddress without 0x prefix
    ///
    // TODO: Remove once EVMAddress.toString() is available
    access(all) view fun getEVMAddressAsHexString(address: EVM.EVMAddress): String {
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
    /// @param: address The hex string to convert to an EVMAddress without the 0x prefix
    ///
    /// @return The EVMAddress representation of the hex string
    ///
    access(all) fun getEVMAddressFromHexString(address: String): EVM.EVMAddress? {
        if address.length != 40 {
            return nil
        }
        var addressBytes: [UInt8] = address.decodeHex()
        if addressBytes.length != 20 {
            return nil
        }
        return EVM.EVMAddress(bytes: [
            addressBytes[0], addressBytes[1], addressBytes[2], addressBytes[3],
            addressBytes[4], addressBytes[5], addressBytes[6], addressBytes[7],
            addressBytes[8], addressBytes[9], addressBytes[10], addressBytes[11],
            addressBytes[12], addressBytes[13], addressBytes[14], addressBytes[15],
            addressBytes[16], addressBytes[17], addressBytes[18], addressBytes[19]
        ])
    }

    /// Identifies if an asset is Cadence- or EVM-native, defined by whether a bridge contract defines it or not
    ///
    /// @param: type The Type of the asset to check
    ///
    /// @return True if the asset is Cadence-native, false if it is EVM-native
    ///
    access(all) view fun isCadenceNative(type: Type): Bool {
        let definingAddress: Address = self.getContractAddress(fromType: type)
            ?? panic("Could not construct address from type identifier: ".concat(type.identifier))
        return definingAddress != self.account.address
    }

    /// Identifies if an asset is Cadence- or EVM-native, defined by whether a bridge-owned contract defines it or not
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
        let callResult: EVM.Result = self.call(
                signature: "isFactoryDeployed(address)",
                targetEVMAddress: self.bridgeFactoryEVMAddress,
                args: [evmContractAddress],
                gasLimit: 60000,
                value: 0.0
            )

        assert(callResult.status == EVM.Status.successful, message: "Call to bridge factory failed")
        let decodedResult: [AnyStruct] = EVM.decodeABI(types: [Type<Bool>()], data: callResult.data)
        assert(decodedResult.length == 1, message: "Invalid response length")

        return decodedResult[0] as! Bool
    }

    /// Identifies if an asset is ERC721
    ///
    access(all) fun isEVMNFT(evmContractAddress: EVM.EVMAddress): Bool {
        let callResult: EVM.Result = self.call(
            signature: "isERC721(address)",
            targetEVMAddress: self.bridgeFactoryEVMAddress,
            args: [evmContractAddress],
            gasLimit: 100000,
            value: 0.0
        )

        assert(callResult.status == EVM.Status.successful, message: "Call to bridge factory failed")
        let decodedResult: [AnyStruct] = EVM.decodeABI(types: [Type<Bool>()], data: callResult.data)
        assert(decodedResult.length == 1, message: "Invalid response length")
        
        return decodedResult[0] as! Bool
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
        let callResult: EVM.Result = self.call(
            signature: "name()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: 60000,
            value: 0.0
        )

        assert(callResult.status == EVM.Status.successful, message: "Call for EVM asset name failed")
        let decodedResult = EVM.decodeABI(types: [Type<String>()], data: callResult.data) as! [AnyStruct]
        assert(decodedResult.length == 1, message: "Invalid response length")

        return decodedResult[0] as! String
    }

    /// Retrieves the NFT/FT symbol from the given EVM contract address - applies for both ERC20 & ERC721
    access(all) fun getSymbol(evmContractAddress: EVM.EVMAddress): String {
        let callResult: EVM.Result = self.call(
            signature: "symbol()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: 60000,
            value: 0.0
        )
        assert(callResult.status == EVM.Status.successful, message: "Call for EVM asset symbol failed")
        let decodedResult = EVM.decodeABI(types: [Type<String>()], data: callResult.data) as! [AnyStruct]
        assert(decodedResult.length == 1, message: "Invalid response length")
        return decodedResult[0] as! String
    }

    /// Retrieves the NFT/FT symbol from the given EVM contract address - applies for both ERC20 & ERC721
    access(all) fun getTokenURI(evmContractAddress: EVM.EVMAddress, id: UInt256): String {
        let callResult: EVM.Result = self.call(
            signature: "tokenURI(uint256)",
            targetEVMAddress: evmContractAddress,
            args: [id],
            gasLimit: 60000,
            value: 0.0
        )
        
        assert(callResult.status == EVM.Status.successful, message: "Call for EVM asset symbol failed")
        let decodedResult = EVM.decodeABI(types: [Type<String>()], data: callResult.data) as! [AnyStruct]
        assert(decodedResult.length == 1, message: "Invalid response length")
        
        return decodedResult[0] as! String
    }

    /// Retrieves the number of decimals for a given ERC20 contract address
    access(all) fun getTokenDecimals(evmContractAddress: EVM.EVMAddress): UInt8 {
        let callResult: EVM.Result = self.call(
                signature: "decimals()",
                targetEVMAddress: evmContractAddress,
                args: [],
                gasLimit: 60000,
                value: 0.0
            )
        
        assert(callResult.status == EVM.Status.successful, message: "Call for EVM asset decimals failed")
        let decodedResult = EVM.decodeABI(types: [Type<UInt8>()], data: callResult.data) as! [AnyStruct]
        assert(decodedResult.length == 1, message: "Invalid response length")

        return decodedResult[0] as! UInt8
    }

    /// Determines if the provided owner address is either the owner or approved for the NFT in the ERC721 contract
    access(all) fun isOwnerOrApproved(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        return self.isOwner(ofNFT: ofNFT, owner: owner, evmContractAddress: evmContractAddress) ||
            self.isApproved(ofNFT: ofNFT, owner: owner, evmContractAddress: evmContractAddress)
    }

    access(all) fun isOwner(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let calldata: [UInt8] = FlowEVMBridgeUtils.encodeABIWithSignature("ownerOf(uint256)", [ofNFT])
        let callResult: EVM.Result = self.borrowCOA().call(
                to: evmContractAddress,
                data: calldata,
                gasLimit: 12000000,
                value: EVM.Balance(attoflow: 0)
            )
        assert(callResult.status == EVM.Status.successful, message: "Call to ERC721.ownerOf(uint256) failed")
        let decodedCallResult: [AnyStruct] = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: callResult.data)
        if decodedCallResult.length == 1 {
            let actualOwner: EVM.EVMAddress = decodedCallResult[0] as! EVM.EVMAddress
            return actualOwner.bytes == owner.bytes
        }
        return false
    }

    access(all) fun isApproved(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let callResult: EVM.Result = self.call(
            signature: "getApproved(uint256)",
            targetEVMAddress: evmContractAddress,
            args: [ofNFT],
            gasLimit: 12000000,
            value: 0.0
        )
        
        assert(callResult.status == EVM.Status.successful, message: "Call to ERC721.getApproved(uint256) failed")
        let decodedCallResult: [AnyStruct] = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: callResult.data)
        if decodedCallResult.length == 1 {
            let actualApproved: EVM.EVMAddress = decodedCallResult[0] as! EVM.EVMAddress
            return actualApproved.bytes == owner.bytes
        }
        return false
    }

    /// Determines if the owner has sufficient funds to bridge the given amount at the ERC20 contract address
    access(all) fun hasSufficientBalance(amount: UFix64, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let callResult: EVM.Result = self.call(
            signature: "balanceOf(address)",
            targetEVMAddress: evmContractAddress,
            args: [owner],
            gasLimit: 60000,
            value: 0.0
        )
        
        assert(callResult.status == EVM.Status.successful, message: "Call to ERC20.balanceOf(address) failed")
        let decodedResult: [UInt256] = EVM.decodeABI(types: [Type<UInt256>()], data: callResult.data) as! [UInt256]
        assert(decodedResult.length == 1, message: "Invalid response length")

        let tokenDecimals: UInt8 = self.getTokenDecimals(evmContractAddress: evmContractAddress)
        return self.uint256ToUFix64(value: decodedResult[0], decimals: tokenDecimals) >= amount
    }

    /// Derives the StoragePath where the escrow locker is stored for a given Type of asset & returns. The given type
    /// must be of an asset supported by the bridge
    ///
    access(all) view fun deriveEscrowStoragePath(fromType: Type): StoragePath? {
        if !self.isValidFlowAsset(type: fromType) {
            return nil
        }
        var prefix = ""
        if fromType.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) {
            prefix = "flowEVMBridgeNFTEscrow"
        } else if fromType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            prefix = "flowEVMBridgeTokenEscrow"
        }
        assert(prefix.length > 1, message: "Invalid prefix")
        if let splitIdentifier: [String] = self.splitObjectIdentifier(identifier: fromType.identifier) {
            let sourceContractAddress: Address = Address.fromString("0x".concat(splitIdentifier[1]))!
            let sourceContractName: String = splitIdentifier[2]
            let resourceName: String = splitIdentifier[3]
            return StoragePath(
                identifier: prefix.concat(self.delimiter)
                    .concat(sourceContractAddress.toString()).concat(self.delimiter)
                    .concat(sourceContractName).concat(self.delimiter)
                    .concat(resourceName)
            ) ?? nil
        }
        return nil
    }

    /// Derives the Cadence contract name for a given EVM NFT of the form
    /// EVMVMBridgedNFT_<0xCONTRACT_ADDRESS>
    access(all) view fun deriveBridgedNFTContractName(from evmContract: EVM.EVMAddress): String {
        return self.contractNamePrefixes[Type<@{NonFungibleToken.NFT}>()]!["bridged"]!
            .concat(self.delimiter)
            .concat("0x".concat(self.getEVMAddressAsHexString(address: evmContract)))
    }
    /// Derives the Cadence contract name for a given EVM fungible token of the form
    /// EVMVMBridgedToken_<0xCONTRACT_ADDRESS>
    access(all) view fun deriveBridgedTokenContractName(from evmContract: EVM.EVMAddress): String {
        return self.contractNamePrefixes[Type<@{FungibleToken.Vault}>()]!["bridged"]!
            .concat(self.delimiter)
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
        // Split identifier of format A.<CONTRACT_ADDRESS>.<CONTRACT_NAME>.<OBJECT_NAME>
        if let identifierSplit: [String] = self.splitObjectIdentifier(identifier: fromType.identifier) {
            return Address.fromString("0x".concat(identifierSplit[1]))
        }
        return nil
    }

    access(all) view fun getContractName(fromType: Type): String? {
        // Split identifier of format A.<CONTRACT_ADDRESS>.<CONTRACT_NAME>.<OBJECT_NAME>
        if let identifierSplit: [String] = self.splitObjectIdentifier(identifier: fromType.identifier) {
            return identifierSplit[2]
        }
        return nil
    }

    access(all) view fun getObjectName(fromType: Type): String? {
        // Split identifier of format A.<CONTRACT_ADDRESS>.<CONTRACT_NAME>.<OBJECT_NAME>
        if let identifierSplit: [String] = self.splitObjectIdentifier(identifier: fromType.identifier) {
            return identifierSplit[3]
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

    /// Validates the Vault used to pay the bridging fee
    access(all) view fun validateFee(_ tollFee: &{FungibleToken.Vault}, onboarding: Bool): Bool {
        pre {
            tollFee.getType() == Type<@FlowToken.Vault>(): "Fee paid in invalid token type"
            onboarding ? tollFee.balance == FlowEVMBridgeConfig.onboardFee : tollFee.balance == FlowEVMBridgeConfig.bridgeFee:
                "Incorrect fee amount paid"
        }
        return true
    }

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
    access(account) fun borrowCOA(): auth(EVM.Owner) &EVM.CadenceOwnedAccount {
        return self.account.storage.borrow<auth(EVM.Owner) &EVM.CadenceOwnedAccount>(
            from: FlowEVMBridgeConfig.coaStoragePath
        ) ?? panic("Could not borrow COA reference")
    }

    /// Shared helper simplifying calls using the bridge account's COA
    access(account) fun call(
        signature: String,
        targetEVMAddress: EVM.EVMAddress,
        args: [AnyStruct],
        gasLimit: UInt64,
        value: UFix64
    ): EVM.Result {
        let calldata: [UInt8] = self.encodeABIWithSignature(signature, args)
        let valueBalance = EVM.Balance(attoflow: 0)
        valueBalance.setFLOW(flow: value)
        return self.borrowCOA().call(
            to: targetEVMAddress,
            data: calldata,
            gasLimit: gasLimit,
            value: valueBalance
        )
    }

    init(bridgeFactoryEVMAddress: String) {
        self.delimiter = "_"
        self.contractNamePrefixes = {
            Type<@{NonFungibleToken.NFT}>(): {
                "bridged": "EVMVMBridgedNFT"
            },
            Type<@{FungibleToken.Vault}>(): {
                "bridged": "EVMVMBridgedToken"
            }
        }
        let bridgeFactoryEVMAddressBytes: [UInt8] = bridgeFactoryEVMAddress.decodeHex()
        self.bridgeFactoryEVMAddress = self.getEVMAddressFromHexString(address: bridgeFactoryEVMAddress)
            ?? panic("Invalid bridge factory EVM address")
    }
}
