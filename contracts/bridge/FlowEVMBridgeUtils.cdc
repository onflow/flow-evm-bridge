import "FlowToken"
import "EVM"

/// Util contract serving all bridge contracts
access(all) contract FlowEVMBridgeUtils {

    /// Address of the bridge factory Solidity contract
    access(all) let bridgeFactoryEVMAddress: EVM.EVMAddress
    /// Commonly used Solidity function selectors to call into EVM from bridge contracts to support call encoding
    /// e.g. ownerOf(uint256)(address), getApproved(uint256)(address), mint(address, uint256), etc.
    access(self) let functionSelectors: {String: [UInt8]}
    /// Contract COA used for inspector calls to Flow EVM
    access(self) let inspectorCOA: @EVM.BridgedAccount

    /// Returns the requested function selector
    access(all) fun getFunctionSelector(signature: String): [UInt8]? {
        return self.functionSelectors[signature]
    }
    /// Returns the address of the contract inspector COA
    access(all) fun getInspectorCOAAddress(): @EVM.EVMAddress {
        return self.inspectorCOA.address()
    }

    /// Identifies if an asset is Flow- or EVM-native, defined by whether a bridge contract defines it or not
    access(all) fun isFlowNative(asset: &AnyResource): Bool {
        // Split identifier of format A.<CONTRACT_ADDRESS>.<CONTRACT_NAME>.<RESOURCE_NAME>
        let identifierSplit: [String] = asset.getType().identifier.split(separator: ".")
        assert(
            identifierSplit.length == 4,
            message: "Malformed type identifier: ".concat(asset.getType().identifier)
        )
        let definingAddress: Address = Address.fromString("0x".concat(identifierSplit[1]))
            ?? panic("Could not construct address from type identifier: ".concat(asset.getType().identifier))
        return definingAddress != self.account.address
    }

    /// Identifies if an asset is Flow- or EVM-native, defined by whether a bridge-owned contract defines it or not
    access(all) fun isEVMNative(evmContractAddress: EVM.EVMAddress): Bool {
        // Ask the bridge factory if the given contract address was deployed by the bridge
        let methodID: [UInt8] = self.getFunctionSelector(signature: "isFlowBridgeDeployed(address)(bool)")
            ?? panic("Problem getting function selector for isFlowBridgeDeployed(address)(bool)")
        let calldata: [UInt8] = methodID.concat(EVM.encodeABI([evmContractAddress]))
        let response = self.inspectorCOA.call(
            to: self.bridgeFactoryEVMAddress,
            data: calldata,
            gasLimit: 60000,
            value: EVM.Balance(flow: 0.0)
        )
        let decodedResponse: [Bool] = EVM.decodeABI(types: [Type<Bool>()], data: response) as [Bool]
        
        // If it was not bridge-deployed, then assume asset is EVM-native
        return decodedResponse[0] == false
    }
    /// Identifies if an asset is ERC721 && not ERC20
    access(all) fun isEVMNFT(evmContractAddress: EVM.EVMAddress): Bool
    /// Identifies if an asset is ERC20 and not ERC721
    access(all) fun isEVMToken(evmContractAddress: EVM.EVMAddress): Bool
    /// Retrieves the number of decimals for a given ERC20 contract address
    access(all) fun getTokenDecimals(evmContractAddress: EVM.EVMAddress): UInt8 {
        let methodID: [UInt8] = self.getFunctionSelector(signature: "decimals()(uint8)")
            ?? panic("Problem getting function selector for decimals()(uint8)")
        let calldata: [UInt8] = methodID.concat(EVM.encodeABI([]))
        let response = self.inspectorCOA.call(
            to: evmContractAddress,
            data: calldata,
            gasLimit: 60000,
            value: EVM.Balance(flow: 0.0)
        )
        let decodedResponse: [UInt8] = EVM.decodeABI(types: [Type<UInt8>()], data: response) as [UInt8]
        return decodedResponse[0]
    }

    /// Determines if the owner is in fact the owner of the NFT at the ERC721 contract address
    access(all) fun isOwnerOrApproved(ofNFT: UInt64, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool

    /// Determines if the owner has sufficient funds to bridge the given amount at the ERC20 contract address
    access(all) fun hasSufficientBalance(amount: UFix64, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let methodID: [UInt8] = self.getFunctionSelector(signature: "balanceOf(address)(uint256)")
            ?? panic("Problem getting function selector for balanceOf(address)(uint256)")
        let calldata: [UInt8] = methodID.concat(EVM.encodeABI([owner]))
        let response = self.inspectorCOA.call(
            to: evmContractAddress,
            data: calldata,
            gasLimit: 60000,
            value: EVM.Balance(flow: 0.0)
        )
        let decodedResponse: [UInt256] = EVM.decodeABI(types: [Type<UInt256>()], data: response) as [UInt256]
        let tokenDecimals: UInt8 = self.getTokenDecimals(evmContractAddress: evmContractAddress)
        return self.uint256ToUFix64(value: decodedResponse[0], decimals: tokenDecimals) >= amount
    }

    /// Derives the Cadence contract name for a given Type
    access(all) fun deriveLockerContractName(fromType: Type): String?
    /// Derives the Cadence contract name for a given EVM asset
    access(all) fun deriveBridgedAssetContractName(fromEVMContract: EVM.EVMAddress): String?

    /* --- Math Utils --- */

    /// Raises the base to the power of the exponent
    access(all) fun pow(base: UInt256, exponent: UInt8): UInt256 {
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
    access(all) fun uint256ToUFix64(value: UInt256, decimals: UInt8): UFix64 {
        let scaleFactor: UInt256 = self.pow(base: 10, exponent: decimals)
        let scaledValue: UInt256 = value / scaleFactor

        assert(scaledValue > UInt256(0xFFFFFFFFFFFFFFFF), message: "Value too large to fit into UFix64")

        return UFix64(scaledValue)
    }
    /// Converts a UFix64 to a UInt256
    access(all) fun ufix64ToUInt256(value: UFix64, decimals: UInt8): UInt256 {
        let integerPart: UInt64 = UInt64(value)
        var r = UInt256(integerPart)

        var multiplier: UInt256 = self.pow(base:10, exponent: decimals)
        return r * multiplier
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

    init(bridgeFactoryEVMAddressBytes: [UInt8; 20]) {
        self.bridgeFactoryEVMAddress = EVM.EVMAddress(bytes: bridgeFactoryEVMAddressBytes)
        let signatures = [
            "decimals()(uint8)",
            "balanceOf(address)(uint256)",
            "ownerOf(uint256)(address)",
            "getApproved(uint256)(address)",
            "approve(address,uint256)",
            "safeMintTo(address,uint256,string)",
            "burn(uint256)",
            "safeTransferFrom(contract IERC20,address,address,uint256)",
            "supportsInterface(bytes4)(bool)",
            "getSymbol()(string)",
            "getName()(string)",
            "isFlowBridgeDeployed(address)(bool)",
            "getFlowAssetContractAddress()(string)",
            "getFlowAssetIdentifier()(string)",
            "isEVMNFT(address)(bool)",
            "isEVMToken(address)(bool)"
        ]
        self.functionSelectors = {}
        for signature in signatures {
            self.upsertFunctionSelector(signature: signature)
        }
        assert(
            self.functionSelectors.length == signatures.length,
            message: "Function selector initialization failed"
        )
        self.inspectorCOA <- EVM.createBridgedAccount()
    }
}
