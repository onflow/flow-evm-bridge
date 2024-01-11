import "NonFungibleToken"
import "FungibleToken"
import "FlowToken"

import "EVM"

/// Util contract serving all bridge contracts
//
// TODO:
// - [ ] Validate bytes4 .sol type can receive [UInt8] from Cadence when encoded - affects supportsInterface calls
// - [ ] Clarify gas limit values for robustness across various network conditions
// - [ ] Implement inspector methods in Factory.sol contract
// - [ ] Consider how calls from inspectorCOA will affect EVM Flow balance and need to rebalance. Maybe use one central account-stored COA.
// - [ ] Remove getEVMAddressAsHexString once EVMAddress.toString() is available
// - [ ] Implement view functions once available in EVM contract
//      - [ ] getInspectorCOAAddress: EVMAddress.address()
//
access(all) contract FlowEVMBridgeUtils {

    /// Address of the bridge factory Solidity contract
    access(all) let bridgeFactoryEVMAddress: EVM.EVMAddress
    /// Delimeter used to derive contract names
    access(self) let contractNameDelimiter: String
    /// Mapping containing contract name prefixes
    access(self) let contractNamePrefixes: {Type: {String: String}}
    /// Mapping of EVM contract interfaces to their 4 byte hash prefixes
    access(self) let interface4Bytes: {String: [UInt8]}
    /// Commonly used Solidity function selectors to call into EVM from bridge contracts to support call encoding
    /// e.g. ownerOf(uint256)(address), getApproved(uint256)(address), mint(address, uint256), etc.
    access(self) let functionSelectors: {String: [UInt8]}
    /// Contract COA used for inspector calls to Flow EVM
    access(self) let inspectorCOA: @EVM.BridgedAccount

    /// Returns the requested function selector
    access(all) view fun getFunctionSelector(signature: String): [UInt8]? {
        return self.functionSelectors[signature]
    }
    /// Returns the address of the contract inspector COA
    access(all) fun getInspectorCOAAddress(): EVM.EVMAddress {
        return self.inspectorCOA.address()
    }
    /// Returns an EVMAddress as a hex string without a 0x prefix
    // TODO: Remove once EVMAddress.toString() is available
    access(all) fun getEVMAddressAsHexString(address: EVM.EVMAddress): String {
        let addressBytes: [UInt8] = []
        for byte in address.bytes {
            addressBytes.append(byte)
        }
        return String.encodeHex(addressBytes)
    }

    /// Identifies if an asset is Flow- or EVM-native, defined by whether a bridge contract defines it or not
    access(all) fun isFlowNative(asset: &AnyResource): Bool {
        let definingAddress: Address = self.getContractAddress(fromType: asset.getType())
            ?? panic("Could not construct address from type identifier: ".concat(asset.getType().identifier))
        return definingAddress != self.account.address
    }

    /// Identifies if an asset is Flow- or EVM-native, defined by whether a bridge-owned contract defines it or not
    access(all) fun isEVMNative(evmContractAddress: EVM.EVMAddress): Bool {
        // Ask the bridge factory if the given contract address was deployed by the bridge
        let response: [UInt8] = self.call(
                signature: "isFlowBridgeDeployed(address)(bool)",
                targetEVMAddress: self.bridgeFactoryEVMAddress,
                args: [evmContractAddress],
                gasLimit: 60000,
                value: 0.0
            )
        let decodedResponse: [Bool] = EVM.decodeABI(types: [Type<Bool>()], data: response) as! [Bool]

        // If it was not bridge-deployed, then assume asset is EVM-native
        return decodedResponse[0] == false
    }

    /// Identifies if an asset is ERC721
    access(all) fun isEVMNFT(evmContractAddress: EVM.EVMAddress): Bool {
        // FLAG - may need to implement supportsInterface in Factory.sol
        let response: [UInt8] = self.call(
            signature: "supportsInterface(bytes4)(bool)",
            targetEVMAddress: evmContractAddress,
            args: [self.interface4Bytes["IERC721"]!],
            gasLimit: 60000,
            value: 0.0
        )
        let decodedResponse: [Bool] = EVM.decodeABI(types: [Type<Bool>()], data: response) as! [Bool]
        return decodedResponse[0]
    }
    /// Identifies if an asset is ERC20
    access(all) fun isEVMToken(evmContractAddress: EVM.EVMAddress): Bool {
        // TODO - Figure out how we can resolve whether a contract is erc20 without erc165
        // FLAG - may need to implement supportsInterface in Factory.sol
        let response: [UInt8] = self.call(
            signature: "supportsInterface(bytes4)(bool)",
            targetEVMAddress: evmContractAddress,
            args: [self.interface4Bytes["IERC20"]!],
            gasLimit: 60000,
            value: 0.0
        )
        return false
    }
    /// Retrieves the NFT/FT name from the given EVM contract address - applies for both ERC20 & ERC721
    access(all) fun getName(evmContractAddress: EVM.EVMAddress): String {
        let response: [UInt8] = self.call(
            signature: "name()(string)",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: 60000,
            value: 0.0
        )
        let decodedResponse: [String] = EVM.decodeABI(types: [Type<String>()], data: response) as! [String]
        return decodedResponse[0]
    }

    /// Retrieves the NFT/FT symbol from the given EVM contract address - applies for both ERC20 & ERC721
    access(all) fun getSymbol(evmContractAddress: EVM.EVMAddress): String {
        let response: [UInt8] = self.call(
            signature: "symbol()(string)",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: 60000,
            value: 0.0
        )
        let decodedResponse: [String] = EVM.decodeABI(types: [Type<String>()], data: response) as! [String]
        return decodedResponse[0]
    }

    /// Retrieves the number of decimals for a given ERC20 contract address
    access(all) fun getTokenDecimals(evmContractAddress: EVM.EVMAddress): UInt8 {
        let response: [UInt8] = self.call(
                signature: "decimals()(uint8)",
                targetEVMAddress: evmContractAddress,
                args: [],
                gasLimit: 60000,
                value: 0.0
            )
        let decodedResponse: [UInt8] = EVM.decodeABI(types: [Type<UInt8>()], data: response) as! [UInt8]
        return decodedResponse[0]
    }

    /// Determines if the owner is in fact the owner of the NFT at the ERC721 contract address
    access(all) fun isOwnerOrApproved(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let ownerResponse: [UInt8] = self.call(
            signature: "ownerOf(uint256)(address)",
            targetEVMAddress: evmContractAddress,
            args: [ofNFT],
            gasLimit: 60000,
            value: 0.0
        )
        let decodedOwnerResponse: [EVM.EVMAddress] = EVM.decodeABI(
                types: [Type<EVM.EVMAddress>()],
                data: ownerResponse
            ) as! [EVM.EVMAddress]
        if decodedOwnerResponse.length == 1 && decodedOwnerResponse[0].bytes == owner.bytes {
            return true
        }

        let approvedResponse: [UInt8] = self.call(
            signature: "getApproved(uint256)(address)",
            targetEVMAddress: evmContractAddress,
            args: [ofNFT],
            gasLimit: 60000,
            value: 0.0
        )
        let decodedApprovedResponse: [EVM.EVMAddress] = EVM.decodeABI(
                types: [Type<EVM.EVMAddress>()],
                data: approvedResponse
            ) as! [EVM.EVMAddress]
        return decodedApprovedResponse.length == 1 && decodedApprovedResponse[0].bytes == owner.bytes
    }

    /// Determines if the owner has sufficient funds to bridge the given amount at the ERC20 contract address
    access(all) fun hasSufficientBalance(amount: UFix64, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let response: [UInt8] = self.call(
            signature: "balanceOf(address)(uint256)",
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
    access(all) fun deriveLockerContractName(fromType: Type): String? {
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
                    .concat(sourceContractAddress.toString()).concat(sourceContractName).concat(resourceName)
            }
        }
        return nil
    }
    /// Derives the Cadence contract name for a given EVM asset of the form
    /// (EVMVMBridgedNFT|EVMVMBridgedToken)_<0xCONTRACT_ADDRESS>
    access(all) fun deriveBridgedAssetContractName(fromEVMContract: EVM.EVMAddress): String? {
        // Determine if the asset is an FT or NFT
        let isToken: Bool = self.isEVMToken(evmContractAddress: fromEVMContract)
        let isNFT: Bool = self.isEVMNFT(evmContractAddress: fromEVMContract)
        let isEVMNative: Bool = self.isEVMNative(evmContractAddress: fromEVMContract)
        // Semi-fungible tokens are not currently supported & Flow-native assets are locked, not bridge-defined
        if (isToken && isNFT) || !isEVMNative {
            return nil
        }

        // Get the NFT or FT name
        let name: String = self.getName(evmContractAddress: fromEVMContract)
        // Concatenate the
        var prefix: String? = nil
        if isToken {
            prefix = self.contractNamePrefixes[Type<@{FungibleToken.Vault}>()]!["bridged"]!
        } else if isNFT {
            prefix = self.contractNamePrefixes[Type<@{NonFungibleToken.NFT}>()]!["bridged"]!
        }
        if prefix != nil {
            return prefix!.concat(self.contractNameDelimiter)
                .concat("0x".concat(self.getEVMAddressAsHexString(address: fromEVMContract)))
        }
        return nil
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

    access(all) fun getContractAddress(fromType: Type): Address? {
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

    access(all) fun splitObjectIdentifier(identifier: String): [String]? {
        let identifierSplit: [String] = identifier.split(separator: ".")
        return identifierSplit.length != 4 ? nil : identifierSplit
    }

    /* --- Bridge-Access Only Utils --- */

    /// Deposits fees to the bridge account's FlowToken Vault - helps fund asset storage
    access(account) fun depositTollFee(_ tollFee: @FlowToken.Vault) {
        let vault = self.account.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken.Vault reference")
        vault.deposit(from: <-tollFee)
    }

    /// Upserts the function selector of the given signature
    access(account) fun upsertFunctionSelector(signature: String) {
        let methodID = HashAlgorithm.KECCAK_256.hash(
            signature.utf8
        ).slice(from: 0, upTo: 4)

        self.functionSelectors[signature] = methodID
    }

    // TODO: Make account method retrieving reference to account stored COA. Determine if we need to limit util getters
    // to prevent spam attacks draining EVM Flow funds
    access(self) fun call(
        signature: String,
        targetEVMAddress: EVM.EVMAddress,
        args: [AnyStruct],
        gasLimit: UInt64,
        value: UFix64
    ): [UInt8] {
        let methodID: [UInt8] = self.getFunctionSelector(signature: signature)
            ?? panic("Problem getting function selector for ".concat(signature))
        let calldata: [UInt8] = methodID.concat(EVM.encodeABI(args))
        let response = self.inspectorCOA.call(
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
        self.interface4Bytes = {
            "IERC20": "80ac58cd".decodeHex(),
            "IERC721": "36372b07".decodeHex()
        }
        let bridgeFactoryEVMAddressBytes: [UInt8] = bridgeFactoryEVMAddress.decodeHex()
        self.bridgeFactoryEVMAddress = EVM.EVMAddress(bytes: [
            bridgeFactoryEVMAddressBytes[0], bridgeFactoryEVMAddressBytes[1], bridgeFactoryEVMAddressBytes[2], bridgeFactoryEVMAddressBytes[3],
            bridgeFactoryEVMAddressBytes[4], bridgeFactoryEVMAddressBytes[5], bridgeFactoryEVMAddressBytes[6], bridgeFactoryEVMAddressBytes[7],
            bridgeFactoryEVMAddressBytes[8], bridgeFactoryEVMAddressBytes[9], bridgeFactoryEVMAddressBytes[10], bridgeFactoryEVMAddressBytes[11],
            bridgeFactoryEVMAddressBytes[12], bridgeFactoryEVMAddressBytes[13], bridgeFactoryEVMAddressBytes[14], bridgeFactoryEVMAddressBytes[15],
            bridgeFactoryEVMAddressBytes[16], bridgeFactoryEVMAddressBytes[17], bridgeFactoryEVMAddressBytes[18], bridgeFactoryEVMAddressBytes[19]
        ])
        let signatures = [
            "decimals()(uint8)",
            "balanceOf(address)(uint256)",
            "ownerOf(uint256)(address)",
            "getApproved(uint256)(address)",
            "approve(address,uint256)",
            "safeMintTo(address,uint256,string)",
            "burn(uint256)",
            "safeTransferFrom(contract IERC20,address,address,uint256)",
            "safeTransferFrom(address,address,uint256)",
            // FLAG - May need to implement supportsInterface in the Factory contract as inspection method until we
            // have clarity on bytes4 type mapping
            "supportsInterface(bytes4)(bool)",
            "symbol()(string)",
            "name()(string)",
            "tokenURI(uint256)(string)",
            "isFlowBridgeDeployed(address)(bool)",
            "getFlowAssetContractAddress()(string)",
            "getFlowAssetIdentifier()(string)",
            "isEVMNFT(address)(bool)",
            "isEVMToken(address)(bool)"
        ]
        self.functionSelectors = {}
        for signature in signatures {
            let methodID = HashAlgorithm.KECCAK_256.hash(
                signature.utf8
            ).slice(from: 0, upTo: 4)
            self.functionSelectors[signature] = methodID
        }
        assert(
            self.functionSelectors.length == signatures.length,
            message: "Function selector initialization failed"
        )
        self.inspectorCOA <- EVM.createBridgedAccount()
    }
}

