import "NonFungibleToken"
import "FungibleToken"
import "MetadataViews"
import "ViewResolver"
import "FlowToken"

import "EVM"

import "FlowEVMBridgeConfig"
import "BridgePermissions"

/// This contract serves as a source of utility methods leveraged by FlowEVMBridge contracts
//
access(all)
contract FlowEVMBridgeUtils {

    /// Address of the bridge factory Solidity contract
    access(all)
    let bridgeFactoryEVMAddress: EVM.EVMAddress
    /// Delimeter used to derive contract names
    access(self)
    let delimiter: String
    /// Mapping containing contract name prefixes
    access(self)
    let contractNamePrefixes: {Type: {String: String}}

    /**************************
        Public Bridge Utils
     **************************/

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

    /// Validates the Vault used to pay the bridging fee
    /// NOTE: Currently fees are calculated at a flat base fee, but may be dynamically calculated based on storage
    ///       used by escrowed assets in the future
    ///
    /// @param used: The amount of storage used by the asset
    /// @param includeBase: Whether to include the base fee in the calculation
    ///
    /// @return The calculated fee amount
    ///
    access(all)
    view fun calculateBridgeFee(used: UInt64, includeBase: Bool): UFix64 {
        return FlowEVMBridgeConfig.baseFee
    }

    /// Returns whether the given type is allowed to be bridged as defined by the BridgePermissions contract interface.
    /// If the type's defining contract does not implement BridgePermissions, the method returns true as the bridge
    /// operates permissionlessly by default. Otherwise, the result of {BridgePermissions}.allowsBridging() is returned
    ///
    /// @param type: The Type of the asset to check
    ///
    /// @return true if the type is allowed to be bridged, false otherwise
    ///
    access(all)
    view fun typeAllowsBridging(_ type: Type): Bool {
        let contractAddress = self.getContractAddress(fromType: type)
            ?? panic("Could not construct contract address from type identifier: ".concat(type.identifier))
        let contractName = self.getContractName(fromType: type)
            ?? panic("Could not construct contract name from type identifier: ".concat(type.identifier))
        if let bridgePermissions = getAccount(contractAddress).contracts.borrow<&{BridgePermissions}>(name: contractName) {
            return bridgePermissions.allowsBridging()
        }
        return true
    }

    /// Returns whether the given address has opted out of enabling bridging for its defined assets. Reverts on EVM call
    /// failure.
    ///
    /// @param address: The EVM contract address to check
    ///
    /// @return false if the address has opted out of enabling bridging, true otherwise
    ///
    access(all)
    fun evmAddressAllowsBridging(_ address: EVM.EVMAddress): Bool {
        let callResult = self.call(
            signature: "allowsBridging()",
            targetEVMAddress: address,
            args: [],
            gasLimit: 60000,
            value: 0.0
        )
        // Contract doesn't support the method - proceed permissionlessly
        if callResult.status != EVM.Status.successful {
            return true
        }
        // Contract is BridgePermissions - return the result
        let decodedResult = EVM.decodeABI(types: [Type<Bool>()], data: callResult.data) as! [AnyStruct]
        return (decodedResult.length == 1 && decodedResult[0] as! Bool) == true ? true : false
    }

    /// Identifies if an asset is Cadence- or EVM-native, defined by whether a bridge contract defines it or not
    ///
    /// @param type: The Type of the asset to check
    ///
    /// @return True if the asset is Cadence-native, false if it is EVM-native
    ///
    access(all)
    view fun isCadenceNative(type: Type): Bool {
        let definingAddress = self.getContractAddress(fromType: type)
            ?? panic("Could not construct address from type identifier: ".concat(type.identifier))
        return definingAddress != self.account.address
    }

    /// Identifies if an asset is Cadence- or EVM-native, defined by whether a bridge-owned contract defines it or not.
    /// Reverts on EVM call failure.
    ///
    /// @param type: The Type of the asset to check
    ///
    /// @return True if the asset is EVM-native, false if it is Cadence-native
    ///
    access(all)
    fun isEVMNative(evmContractAddress: EVM.EVMAddress): Bool {
        return self.isEVMContractBridgeOwned(evmContractAddress: evmContractAddress) == false
    }

    /// Determines if the given EVM contract address was deployed by the bridge by querying the factory contract
    /// Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to check
    ///
    /// @return True if the contract was deployed by the bridge, false otherwise
    ///
    access(all)
    fun isEVMContractBridgeOwned(evmContractAddress: EVM.EVMAddress): Bool {
        // Ask the bridge factory if the given contract address was deployed by the bridge
        let callResult = self.call(
                signature: "isFactoryDeployed(address)",
                targetEVMAddress: self.bridgeFactoryEVMAddress,
                args: [evmContractAddress],
                gasLimit: 60000,
                value: 0.0
            )

        assert(callResult.status == EVM.Status.successful, message: "Call to bridge factory failed")
        let decodedResult = EVM.decodeABI(types: [Type<Bool>()], data: callResult.data)
        assert(decodedResult.length == 1, message: "Invalid response length")

        return decodedResult[0] as! Bool
    }

    /// Identifies if an asset is ERC721. Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to check
    ///
    /// @return True if the asset is an ERC721, false otherwise
    ///
    access(all)
    fun isEVMNFT(evmContractAddress: EVM.EVMAddress): Bool {
        let callResult = self.call(
            signature: "isERC721(address)",
            targetEVMAddress: self.bridgeFactoryEVMAddress,
            args: [evmContractAddress],
            gasLimit: 100000,
            value: 0.0
        )

        assert(callResult.status == EVM.Status.successful, message: "Call to bridge factory failed")
        let decodedResult = EVM.decodeABI(types: [Type<Bool>()], data: callResult.data)
        assert(decodedResult.length == 1, message: "Invalid response length")

        return decodedResult[0] as! Bool
    }

    /// Identifies if an asset is ERC20
    ///
    access(all)
    fun isEVMToken(evmContractAddress: EVM.EVMAddress): Bool {
        // TODO: We will need to figure out how to identify ERC20s without ERC165 support
        return false
    }

    /// Returns whether the contract address is either an ERC721 or ERC20 exclusively. Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to check
    ///
    /// @return True if the contract is either an ERC721 or ERC20, false otherwise
    ///
    access(all)
    fun isValidEVMAsset(evmContractAddress: EVM.EVMAddress): Bool {
        let isEVMNFT = FlowEVMBridgeUtils.isEVMNFT(evmContractAddress: evmContractAddress)
        let isEVMToken = FlowEVMBridgeUtils.isEVMToken(evmContractAddress: evmContractAddress)
        return (isEVMNFT && !isEVMToken) || (!isEVMNFT && isEVMToken)
    }

    /// Returns whether the given type is either an NFT or FT exclusively
    ///
    /// @param type: The Type of the asset to check
    ///
    /// @return True if the type is either an NFT or FT, false otherwise
    ///
    access(all)
    view fun isValidFlowAsset(type: Type): Bool {
        let isFlowNFT = type.isSubtype(of: Type<@{NonFungibleToken.NFT}>())
        let isFlowToken = type.isSubtype(of: Type<@{FungibleToken.Vault}>())
        return (isFlowNFT && !isFlowToken) || (!isFlowNFT && isFlowToken)
    }

    /************************
        EVM Call Wrappers
     ************************/

    /// Retrieves the NFT/FT name from the given EVM contract address - applies for both ERC20 & ERC721.
    /// Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve the name from
    ///
    /// @return the name of the asset
    ///
    access(all)
    fun getName(evmContractAddress: EVM.EVMAddress): String {
        let callResult = self.call(
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
    /// Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve the symbol from
    ///
    /// @return the symbol of the asset
    ///
    access(all)
    fun getSymbol(evmContractAddress: EVM.EVMAddress): String {
        let callResult = self.call(
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
    /// Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve the tokenURI from
    /// @param id: The ID of the NFT for which to retrieve the tokenURI value
    ///
    /// @return the tokenURI of the ERC721
    ///
    access(all)
    fun getTokenURI(evmContractAddress: EVM.EVMAddress, id: UInt256): String {
        let callResult = self.call(
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

    /// Retrieves the contract URI from the given EVM contract address. Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve the contractURI from
    ///
    /// @return the contract's contractURI
    ///
    access(all)
    fun getContractURI(evmContractAddress: EVM.EVMAddress): String? {
        let callResult = self.call(
            signature: "contractURI()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: 60000,
            value: 0.0
        )
        if callResult.status != EVM.Status.successful {
            return nil
        }
        let decodedResult = EVM.decodeABI(types: [Type<String>()], data: callResult.data) as! [AnyStruct]
        return decodedResult.length == 1 ? decodedResult[0] as! String : nil
    }

    /// Retrieves the number of decimals for a given ERC20 contract address. Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The ERC20 contract address to retrieve the token decimals from
    ///
    /// @return the token decimals of the ERC20
    ///
    access(all)
    fun getTokenDecimals(evmContractAddress: EVM.EVMAddress): UInt8 {
        let callResult = self.call(
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
    /// Reverts on EVM call failure.
    ///
    /// @param ofNFT: The ID of the NFT to query
    /// @param owner: The owner address to query
    /// @param evmContractAddress: The ERC721 contract address to query
    ///
    /// @return true if the owner is either the owner or approved for the NFT, false otherwise
    ///
    access(all)
    fun isOwnerOrApproved(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        return self.isOwner(ofNFT: ofNFT, owner: owner, evmContractAddress: evmContractAddress) ||
            self.isApproved(ofNFT: ofNFT, owner: owner, evmContractAddress: evmContractAddress)
    }

    /// Returns whether the given owner is the owner of the given NFT. Reverts on EVM call failure.
    ///
    /// @param ofNFT: The ID of the NFT to query
    /// @param owner: The owner address to query
    /// @param evmContractAddress: The ERC721 contract address to query
    ///
    /// @return true if the owner is in fact the owner of the NFT, false otherwise
    ///
    access(all)
    fun isOwner(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let calldata = EVM.encodeABIWithSignature("ownerOf(uint256)", [ofNFT])
        let callResult = self.borrowCOA().call(
                to: evmContractAddress,
                data: calldata,
                gasLimit: 12000000,
                value: EVM.Balance(attoflow: 0)
            )
        assert(callResult.status == EVM.Status.successful, message: "Call to ERC721.ownerOf(uint256) failed")
        let decodedCallResult = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: callResult.data)
        if decodedCallResult.length == 1 {
            let actualOwner = decodedCallResult[0] as! EVM.EVMAddress
            return actualOwner.bytes == owner.bytes
        }
        return false
    }

    /// Returns whether the given owner is approved for the given NFT. Reverts on EVM call failure.
    ///
    /// @param ofNFT: The ID of the NFT to query
    /// @param owner: The owner address to query
    /// @param evmContractAddress: The ERC721 contract address to query
    ///
    /// @return true if the owner is in fact approved for the NFT, false otherwise
    ///
    access(all)
    fun isApproved(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let callResult = self.call(
            signature: "getApproved(uint256)",
            targetEVMAddress: evmContractAddress,
            args: [ofNFT],
            gasLimit: 12000000,
            value: 0.0
        )

        assert(callResult.status == EVM.Status.successful, message: "Call to ERC721.getApproved(uint256) failed")
        let decodedCallResult = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: callResult.data)
        if decodedCallResult.length == 1 {
            let actualApproved = decodedCallResult[0] as! EVM.EVMAddress
            return actualApproved.bytes == owner.bytes
        }
        return false
    }

    /// Determines if the owner has sufficient funds to bridge the given amount at the ERC20 contract address
    /// Reverts on EVM call failure.
    ///
    /// @param amount: The amount to check if the owner has enough balance to cover
    /// @param owner: The owner address to query
    /// @param evmContractAddress: The ERC20 contract address to query
    ///
    /// @return true if the owner's balance >= amount, false otherwise
    ///
    access(all)
    fun hasSufficientBalance(amount: UFix64, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let callResult = self.call(
            signature: "balanceOf(address)",
            targetEVMAddress: evmContractAddress,
            args: [owner],
            gasLimit: 60000,
            value: 0.0
        )

        assert(callResult.status == EVM.Status.successful, message: "Call to ERC20.balanceOf(address) failed")
        let decodedResult = EVM.decodeABI(types: [Type<UInt256>()], data: callResult.data) as! [UInt256]
        assert(decodedResult.length == 1, message: "Invalid response length")

        let tokenDecimals = self.getTokenDecimals(evmContractAddress: evmContractAddress)
        return self.uint256ToUFix64(value: decodedResult[0], decimals: tokenDecimals) >= amount
    }

    /************************
        Derivation Utils
     ************************/

    /// Derives the StoragePath where the escrow locker is stored for a given Type of asset & returns. The given type
    /// must be of an asset supported by the bridge.
    ///
    /// @param fromType: The type of the asset the escrow locker is being derived for
    ///
    /// @return The StoragePath associated with the type's escrow Locker, or nil if the type is not supported
    ///
    access(all)
    view fun deriveEscrowStoragePath(fromType: Type): StoragePath? {
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
        if let splitIdentifier = self.splitObjectIdentifier(identifier: fromType.identifier) {
            let sourceContractAddress = Address.fromString("0x".concat(splitIdentifier[1]))!
            let sourceContractName = splitIdentifier[2]
            let resourceName = splitIdentifier[3]
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
    ///
    /// @param from evmContract: The EVM contract address to derive the Cadence NFT contract name for
    ///
    /// @return The derived Cadence FT contract name
    ///
    access(all)
    view fun deriveBridgedNFTContractName(from evmContract: EVM.EVMAddress): String {
        return self.contractNamePrefixes[Type<@{NonFungibleToken.NFT}>()]!["bridged"]!
            .concat(self.delimiter)
            .concat("0x".concat(self.getEVMAddressAsHexString(address: evmContract)))
    }

    /// Derives the Cadence contract name for a given EVM fungible token of the form
    /// EVMVMBridgedToken_<0xCONTRACT_ADDRESS>
    ///
    /// @param from evmContract: The EVM contract address to derive the Cadence FT contract name for
    ///
    /// @return The derived Cadence FT contract name
    ///
    access(all)
    view fun deriveBridgedTokenContractName(from evmContract: EVM.EVMAddress): String {
        return self.contractNamePrefixes[Type<@{FungibleToken.Vault}>()]!["bridged"]!
            .concat(self.delimiter)
            .concat("0x".concat(self.getEVMAddressAsHexString(address: evmContract)))
    }

    /****************
        Math Utils
     ****************/

    /// Raises the base to the power of the exponent
    ///
    access(all)
    view fun pow(base: UInt256, exponent: UInt8): UInt256 {
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
    ///
    access(all)
    view fun uint256ToUFix64(value: UInt256, decimals: UInt8): UFix64 {
        let scaleFactor: UInt256 = self.pow(base: 10, exponent: decimals)
        let scaledValue: UInt256 = value / scaleFactor

        assert(scaledValue > UInt256(UInt64.max), message: "Value too large to fit into UFix64")

        return UFix64(scaledValue)
    }

    /// Converts a UFix64 to a UInt256
    //
    access(all)
    view fun ufix64ToUInt256(value: UFix64, decimals: UInt8): UInt256 {
        let integerPart: UInt64 = UInt64(value)
        var r = UInt256(integerPart)

        var multiplier: UInt256 = self.pow(base:10, exponent: decimals)
        return r * multiplier
    }

    /// Returns the value as a UInt64 if it fits, otherwise panics
    ///
    access(all)
    view fun uint256ToUInt64(value: UInt256): UInt64 {
        return value <= UInt256(UInt64.max) ? UInt64(value) : panic("Value too large to fit into UInt64")
    }

    /***************************
        Type Identifier Utils
     ***************************/

    /// Returns the contract address from the given Type's identifier
    ///
    /// @param fromType: The Type to extract the contract address from
    ///
    /// @return The defining contract's Address, or nil if the identifier does not have an associated Address
    ///
    access(all)
    view fun getContractAddress(fromType: Type): Address? {
        // Split identifier of format A.<CONTRACT_ADDRESS>.<CONTRACT_NAME>.<OBJECT_NAME>
        if let identifierSplit = self.splitObjectIdentifier(identifier: fromType.identifier) {
            return Address.fromString("0x".concat(identifierSplit[1]))
        }
        return nil
    }

    /// Returns the contract name from the given Type's identifier
    ///
    /// @param fromType: The Type to extract the contract name from
    ///
    /// @return The defining contract's name, or nil if the identifier does not have an associated contract name
    ///
    access(all)
    view fun getContractName(fromType: Type): String? {
        // Split identifier of format A.<CONTRACT_ADDRESS>.<CONTRACT_NAME>.<OBJECT_NAME>
        if let identifierSplit = self.splitObjectIdentifier(identifier: fromType.identifier) {
            return identifierSplit[2]
        }
        return nil
    }

    /// Returns the object's name from the given Type's identifier
    ///
    /// @param fromType: The Type to extract the object name from
    ///
    /// @return The object's name, or nil if the identifier does identify an object
    ///
    access(all)
    view fun getObjectName(fromType: Type): String? {
        // Split identifier of format A.<CONTRACT_ADDRESS>.<CONTRACT_NAME>.<OBJECT_NAME>
        if let identifierSplit = self.splitObjectIdentifier(identifier: fromType.identifier) {
            return identifierSplit[3]
        }
        return nil
    }

    /// Splits the given identifier into its constituent parts defined by a delimiter of '".'"
    ///
    /// @param identifier: The identifier to split
    ///
    /// @return An array of the identifier's constituent parts, or nil if the identifier does not have 4 parts
    ///
    access(all)
    view fun splitObjectIdentifier(identifier: String): [String]? {
        let identifierSplit = identifier.split(separator: ".")
        return identifierSplit.length != 4 ? nil : identifierSplit
    }

    /// Builds a composite type from the given identifier parts
    ///
    /// @param address: The defining contract address
    /// @param contractName: The defining contract name
    /// @param resourceName: The resource name
    ///
    access(all)
    view fun buildCompositeType(address: Address, contractName: String, resourceName: String): Type? {
        let addressStr = address.toString()
        let subtract0x = addressStr.slice(from: 2, upTo: addressStr.length)
        let identifier = "A".concat(".").concat(subtract0x).concat(".").concat(contractName).concat(".").concat(resourceName)
        return CompositeType(identifier)
    }

    /******************************
        Bridge-Access Only Utils
     ******************************/

    /// Deposits fees to the bridge account's FlowToken Vault - helps fund asset storage
    ///
    access(account)
    fun deposit(_ feeVault: @FlowToken.Vault) {
        let vault = self.account.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken.Vault reference")
        vault.deposit(from: <-feeVault)
    }

    /// Enables other bridge contracts to orchestrate bridge operations from contract-owned COA
    ///
    access(account)
    view fun borrowCOA(): auth(EVM.Owner) &EVM.CadenceOwnedAccount {
        return self.account.storage.borrow<auth(EVM.Owner) &EVM.CadenceOwnedAccount>(
            from: FlowEVMBridgeConfig.coaStoragePath
        ) ?? panic("Could not borrow COA reference")
    }

    /// Shared helper simplifying calls using the bridge account's COA
    ///
    access(account)
    fun call(
        signature: String,
        targetEVMAddress: EVM.EVMAddress,
        args: [AnyStruct],
        gasLimit: UInt64,
        value: UFix64
    ): EVM.Result {
        let calldata = EVM.encodeABIWithSignature(signature, args)
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
