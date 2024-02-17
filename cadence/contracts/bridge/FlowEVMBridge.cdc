import "FungibleToken"
import "NonFungibleToken"
import "FlowToken"

import "EVM"

import "ICrossVM"
import "CrossVMAsset"
import "IFlowEVMNFTBridge"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"
import "IEVMBridgeNFTLocker"
import "FlowEVMBridgeTemplates"

/// The FlowEVMBridge contract is the main entrypoint for bridging NFT & FT assets between Flow & FlowEVM.
///
/// Before bridging, be sure to onboard the asset type which will configure the bridge to handle the asset. From there,
/// the asset can be bridged between VMs using the public entrypoints below, the only distinctions being the type of
/// asset being bridged (NFT vs FT) and the direction of bridging (to or from EVM).
///
/// See also:
/// - Code in context: https://github.com/onflow/flow-evm-bridge
/// - FLIP #237: https://github.com/onflow/flips/pull/233
///
access(all) contract FlowEVMBridge {

    /* --- Events --- */
    //
    /// Denotes a Locker contract was deployed to the bridge account
    access(all) event BridgeLockerContractDeployed(lockedType: Type, contractName: String, evmContractAddress: EVM.EVMAddress)
    /// Denotes a defining contract was deployed to the bridge accountcode
    access(all) event BridgeDefiningContractDeployed(
        contractName: String,
        assetName: String,
        symbol: String,
        isERC721: Bool,
        evmContractAddress: EVM.EVMAddress
    )

    /**************************
        Public NFT Handling
    **************************/

    /// Onboards a given asset by type to the bridge. Since we're onboarding by Cadence Type, the asset must be defined
    /// in a third-party contract. Attempting to onboard a bridge-defined asset will result in an error as onboarding
    /// is not required
    ///
    /// @param type: The Cadence Type of the NFT to be onboarded
    /// @param tollFee: Fee paid for onboarding
    ///
    access(all) fun onboardByType(_ type: Type, tollFee: @{FungibleToken.Vault}) {
        pre {
            tollFee.getType() == Type<@FlowToken.Vault>(): "Fee paid in invalid token type"
            self.typeRequiresOnboarding(type) == true: "Onboarding is not needed for this type"
            FlowEVMBridgeUtils.isValidFlowAsset(type: type): "Invalid type provided"
        }
        if type.isSubtype(of: Type<@{CrossVMAsset.BridgeableAsset}>()) {
            panic("Asset is already bridgeable and does not require onboarding to this bridge")
        }
        FlowEVMBridgeUtils.depositTollFee(<-tollFee)
        assert(FlowEVMBridgeUtils.isFlowNative(type: type), message: "Only Flow-native assets can be onboarded by Type")
        self.deployLockerContract(forType: type)
    }

    /// Onboards a given ERC721 to the bridge. Since we're onboarding by EVM Address, the asset must be defined in a
    /// third-party EVM contract. Attempting to onboard a bridge-defined asset will result in an error as onboarding is
    /// not required
    ///
    /// @param address: The EVMAddress of the ERC721 or ERC20 to be onboarded
    /// @param tollFee: Fee paid for onboarding
    ///
    access(all) fun onboardByEVMAddress(_ address: EVM.EVMAddress, tollFee: @{FungibleToken.Vault}) {
        pre {
            tollFee.getType() == Type<@FlowToken.Vault>(): "Fee paid in invalid token type"
            tollFee.getBalance() >= FlowEVMBridgeConfig.fee: "Insufficient fee paid"
        }
        // TODO: Add bridge association check once tryCall is implemented, until then we can't check if the EVM contract
        //      is associated with a self-rolled bridge without reverting on failure
        FlowEVMBridgeUtils.depositTollFee(<-tollFee)
        assert(
            self.evmAddressRequiresOnboarding(address) == true,
            message: "Onboarding is not needed for this contract"
        )
        self.deployDefiningContract(evmContractAddress: address)
    }

    /// Public entrypoint to bridge NFTs from Flow to EVM - cross-account bridging supported (e.g. straight to EOA)
    ///
    /// @param token: The NFT to be bridged
    /// @param to: The NFT recipient in FlowEVM
    /// @param tollFee: The fee paid for bridging
    ///
    access(all) fun bridgeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @{FungibleToken.Vault}) {
        pre {
            tollFee.getBalance() >= FlowEVMBridgeConfig.fee: "Insufficient fee paid"
            tollFee.getType() == Type<@FlowToken.Vault>(): "Fee paid in invalid token type"
            token.isInstance(Type<@{FungibleToken.Vault}>()) == false: "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(token.getType()) == false: "NFT must first be onboarded"
        }
        // Passthrough to the asset's default bridge contract if it's defined by the token's contract
        if token.getType().isSubtype(of: Type<@{CrossVMAsset.BridgeableAsset}>()) && self.tryNFTPassthrough(token: &token) {
            self.passthroughNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
            return
        }
        if FlowEVMBridgeUtils.isFlowNative(type: token.getType()) {
            // Otherwise, pass through to bridge-owned locker contract
            self.bridgeFlowNativeNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
            return
        }
        panic("Problem bridging NFT to EVM")
    }

    /// Public entrypoint to bridge NFTs from EVM to Flow
    ///
    /// @param caller: The caller executing the bridge - must be passed to check EVM state pre- & post-call in scope
    /// @param calldata: Caller-provided approve() call, enabling contract COA to operate on NFT in EVM contract
    /// @param id: The NFT ID to bridged
    /// @param evmContractAddress: Address of the EVM address defining the NFT being bridged - also call target
    /// @param tollFee: The fee paid for bridging
    ///
    /// @returns The bridged NFT
    ///
    access(all) fun bridgeNFTFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @{FungibleToken.Vault}
    ): @{NonFungibleToken.NFT} {
        pre {
            tollFee.getBalance() >= FlowEVMBridgeConfig.fee: "Insufficient fee paid"
            tollFee.getType() == Type<@FlowToken.Vault>(): "Fee paid in invalid token type"
        }
        // TODO: Add bridge association check once tryCall is implemented, until then we can't check if the EVM contract
        //      is associated with a self-rolled bridge without reverting on failure
        if FlowEVMBridgeUtils.isEVMNative(evmContractAddress: evmContractAddress) {
            return <- self.bridgeEVMNativeNFTFromEVM(
                caller: caller,
                calldata: calldata,
                id: id,
                evmContractAddress: evmContractAddress,
                tollFee: <-tollFee
            )
        }
        return <- self.bridgeFlowNativeNFTFromEVM(
            caller: caller,
            calldata: calldata,
            id: id,
            evmContractAddress: evmContractAddress,
            tollFee: <-tollFee
        )
    }

    /**************************
        Public FT Handling
    ***************************/
    // TODO

    /**************************
        Public Getters
    **************************/

    /// Retrieves the bridge contract's COA EVMAddress
    ///
    /// @returns The EVMAddress of the bridge contract's COA orchestrating actions in FlowEVM
    ///
    // TODO: Can be made `view` when BridgedAccount.address() is `view`
    access(all) fun getBridgeCOAEVMAddress(): EVM.EVMAddress {
        return FlowEVMBridgeUtils.borrowCOA().address()
    }

    /// Retrieves the EVM address of the contract related to the bridge contract-defined asset
    /// Useful for bridging flow-native assets back from EVM
    ///
    /// @param type: The Cadence Type of the asset
    ///
    /// @returns The EVMAddress of the contract defining the asset
    ///
    access(all) fun getAssetEVMContractAddress(type: Type): EVM.EVMAddress? {
        if self.typeRequiresOnboarding(type) != false {
            return nil
        }
        if FlowEVMBridgeUtils.isFlowNative(type: type) {
            if let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: type) {
                return self.account.contracts.borrow<&ICrossVM>(name: lockerContractName)?.getEVMContractAddress() ?? nil
            }
        } else {
            if let assetContractName: String = FlowEVMBridgeUtils.getContractName(fromType: type) {
                return self.account.contracts.borrow<&ICrossVM>(name: assetContractName)?.getEVMContractAddress() ?? nil
            }
        }
        return nil
    }

    /// Retrieves the Flow address associated with the asset defined at the provided EVM address if it's defined
    /// in a bridge-deployed contract
    // Only succeeds for bridge-deployed EVM contract Addresses. Returns nil if the contract is not bridge-deployed
    // access(all) fun getAssetFlowContractAddress(evmAddress: EVM.EVMAddress): Address?

    /// Returns whether an asset needs to be onboarded to the bridge
    ///
    /// @param type: The Cadence Type of the asset
    ///
    /// @returns Whether the asset needs to be onboarded
    ///
    access(all) view fun typeRequiresOnboarding(_ type: Type): Bool? {
        // If type is not an NFT or FT type, it's not supported - return nil
        if !type.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) && !type.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            return nil
        }

        // If the type is a CrossVMAsset.BridgeableAsset implementation, it has a default bridge address and does not
        // require onboarding. This includes all FTs & NFTs defined by contracts deployed to this bridge account.
        if type.isSubtype(of: Type<@{CrossVMAsset.BridgeableAsset}>()) {
            return false
        }

        // Otherwise, the type is Flow-native, so check if the locker contract is deployed
        if let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: type) {
            return self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName) == nil
        }

        return nil
    }

    /// Returns whether an EVM-native asset needs to be onboarded to the bridge
    access(all) fun evmAddressRequiresOnboarding(_ address: EVM.EVMAddress): Bool? {
        // If the address was deployed by the bridge, it's via Flow-native asset path
        if FlowEVMBridgeUtils.isEVMContractBridgeOwned(evmContractAddress: address) {
            return false
        }
        // Dealing with EVM-native asset, check if it's NFT or FT exclusively
        if FlowEVMBridgeUtils.isValidEVMAsset(evmContractAddress: address) {
            return true
        }
        // Neither, so return nil
        return nil
    }

    /// Borrows the locker contract from the bridge account for the given asset type
    ///
    /// @param forType: The Cadence Type of the asset
    ///
    /// @returns The locker contract handling the asset type or nil if non-existent
    ///
    access(all) view fun borrowLockerContract(forType: Type): &IEVMBridgeNFTLocker? {
        if let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: forType) {
            return self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName)
        }
        return nil
    }

    /**************************
        Internal Helpers
    ***************************/

    /// Handles bridging Flow-native NFTs to EVM - locks NFT in designated Flow locker contract & mints in EVM.
    /// Within scope, locker contract is deployed if needed & call is passed on to said locker contract.
    ///
    access(self) fun bridgeFlowNativeNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        tollFee: @{FungibleToken.Vault}
    ) {
        let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: token.getType()) ??
            panic("Could not derive locker contract name for token type: ".concat(token.getType().identifier))
        if self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName) == nil {
            self.deployLockerContract(forType: token.getType())
        }

        let lockerContract: &IEVMBridgeNFTLocker = self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName)
            ?? panic("Problem locating Locker contract for token type: ".concat(token.getType().identifier))
        lockerContract.bridgeNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
    }
    /// Handles bridging Flow-native NFTs from EVM - unlocks NFT from designated Flow locker contract & burns in EVM
    /// Within scope, locker contract is deployed if needed & passing on call to said contract
    ///
    access(self) fun bridgeFlowNativeNFTFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @{FungibleToken.Vault}
    ): @{NonFungibleToken.NFT} {
        let response: [UInt8] = FlowEVMBridgeUtils.call(
            signature: "getFlowAssetIdentifier(address)",
            targetEVMAddress: FlowEVMBridgeUtils.bridgeFactoryEVMAddress,
            args: [evmContractAddress],
            gasLimit: 15000000,
            value: 0.0
        )
        let decodedResponse: [AnyStruct] = EVM.decodeABI(types: [Type<String>()], data: response)
        let identifier: String = decodedResponse[0] as! String
        let lockedType: Type = CompositeType(identifier) ?? panic("Invalid identifier returned from EVM contract")
        let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: lockedType) ??
            panic("Could not derive locker contract name for token type: ".concat(lockedType.identifier))
        let lockerContract: &IEVMBridgeNFTLocker = self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName)
            ?? panic("Problem configuring Locker contract for token type: ".concat(lockedType.identifier))
        return <- lockerContract.bridgeNFTFromEVM(
            caller: caller,
            calldata: calldata,
            id: id,
            evmContractAddress: evmContractAddress,
            tollFee: <-tollFee
        )
    }

    /// Attempts to retrieve the bridging contract for NFT, returning true if it conforms to
    /// CrossVMAsset.BridgeableAsset and returns a reference to &IFlowEVMNFTBridge contract interface as its default
    /// bridge contract
    ///
    access(self) fun tryNFTPassthrough(token: &{NonFungibleToken.NFT}): Bool {
        if let bridgeableAsset: &{CrossVMAsset.BridgeableAsset} = token as? &{CrossVMAsset.BridgeableAsset} {
            if let bridgeContract = bridgeableAsset.borrowDefaultBridgeContract() as? &IFlowEVMNFTBridge {
                log("PASSTHROUGH DRY RUN SUCCESSFUL")
                return true
            }
        }
        log("PASSTHROUGH DRY RUN FAILURE")
        return false
    }

    /// Passes through the bridge call to the default bridge contract of the NFT according to
    /// CrossVMAsset.BridgeableAsset and &IFlowEVMNFTBridge interfaces
    ///
    access(self) fun passthroughNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @{FungibleToken.Vault}) {
        // This call passes the bridge request, but the tollFee may not be sufficient to cover the request as
        // that value is not defined by this bridge contract
        let tokenRef: &{NonFungibleToken.NFT} = &token
        let bridgeableAsset = tokenRef as! &{CrossVMAsset.BridgeableAsset}
        let bridgeContract = bridgeableAsset.borrowDefaultBridgeContract() as! &IFlowEVMNFTBridge
        bridgeContract.bridgeNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
    }

    /// Handles bridging Flow-native NFTs from EVM - unlocks NFT from designated Flow locker contract & burns in EVM
    /// Within scope, locker contract is deployed if needed & passing on call to said contract
    ///
    access(self) fun bridgeEVMNativeNFTFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @{FungibleToken.Vault}
    ): @{NonFungibleToken.NFT} {
        // Derive the bridged NFT contract name
        let contractName = FlowEVMBridgeUtils.deriveBridgedNFTContractName(from: evmContractAddress)
        let bridgedNFTContract = self.account.contracts.borrow<&IFlowEVMNFTBridge>(name: contractName)
            ?? panic("Could not borrow the bridged NFT contract for this EVM-native NFT")
        return <- bridgedNFTContract.bridgeNFTFromEVM(
            caller: caller,
            calldata: calldata,
            id: id,
            evmContractAddress: evmContractAddress,
            tollFee: <-tollFee
        )
    }

    /// Helper for deploying templated Locker contract supporting Flow-native asset bridging to EVM
    /// Deploys either NFT or FT locker depending on the asset type
    ///
    /// @param forType: The Cadence Type of the asset
    ///
    access(self) fun deployLockerContract(forType: Type) {
        let evmContractAddress: EVM.EVMAddress = self.deployEVMContract(forAssetType: forType)

        let code: [UInt8] = FlowEVMBridgeTemplates.getLockerContractCode(forType: forType)
            ?? panic("Could not retrieve code for given asset type: ".concat(forType.identifier))
        let name: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: forType)
            ?? panic("Could not derive locker contract name for token type: ".concat(forType.identifier))
        let contractAddress: Address = FlowEVMBridgeUtils.getContractAddress(fromType: forType)
            ?? panic("Could not derive locker contract address for token type: ".concat(forType.identifier))
        self.account.contracts.add(name: name, code: code, forType, contractAddress, evmContractAddress)

        emit BridgeLockerContractDeployed(lockedType: forType, contractName: name, evmContractAddress: evmContractAddress)
    }

    /// Deploys templated EVM contract via Solidity Factory contract supporting bridging of a given asset type
    ///
    /// @param forAssetType: The Cadence Type of the asset
    ///
    /// @returns The EVMAddress of the deployed contract
    ///
    access(self) fun deployEVMContract(forAssetType: Type): EVM.EVMAddress {
        if forAssetType.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) {
            return self.deployERC721(forAssetType)
        } else if forAssetType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            // TODO
            // return self.deployERC20(name: forAssetType.identifier)
        }
        panic("Unsupported asset type: ".concat(forAssetType.identifier))
    }

    access(self) fun deployERC721(_ forNFTType: Type): EVM.EVMAddress {
        let name: String = FlowEVMBridgeUtils.getContractName(fromType: forNFTType)
            ?? panic("Could not contract name from type: ".concat(forNFTType.identifier))
        let identifier: String = forNFTType.identifier
        let cadenceAddressStr: String = FlowEVMBridgeUtils.getContractAddress(fromType: forNFTType)?.toString()
            ?? panic("Could not derive contract address for token type: ".concat(identifier))

        let response: [UInt8] = FlowEVMBridgeUtils.call(
            signature: "deployERC721(string,string,string,string)",
            targetEVMAddress: FlowEVMBridgeUtils.bridgeFactoryEVMAddress,
            args: [name, "BRDG", cadenceAddressStr, identifier],
            gasLimit: 15000000,
            value: 0.0
        )
        let decodedResponse: [AnyStruct] = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: response)
        let erc721Address: EVM.EVMAddress = decodedResponse[0] as! EVM.EVMAddress
        return erc721Address
    }

    /// Helper for deploying templated defining contract supporting EVM-native asset bridging to Flow
    /// Deploys either NFT or FT contract depending on the provided type
    ///
    access(self) fun deployDefiningContract(evmContractAddress: EVM.EVMAddress) {
        // Deploy the Cadence contract defining the asset
        // Treat as NFT if ERC721, otherwise FT
        let name: String = FlowEVMBridgeUtils.getName(evmContractAddress: evmContractAddress)
        let symbol: String = FlowEVMBridgeUtils.getSymbol(evmContractAddress: evmContractAddress)
        // Derive contract name
        let isERC721: Bool = FlowEVMBridgeUtils.isEVMNFT(evmContractAddress: evmContractAddress)
        let cadenceContractName: String = FlowEVMBridgeUtils.deriveBridgedNFTContractName(from: evmContractAddress)
        // Get code
        let cadenceCode: [UInt8] = FlowEVMBridgeTemplates.getBridgedAssetContractCode(
                evmContractAddress: evmContractAddress,
                isERC721: isERC721
            ) ?? panic("Problem retrieving code for Cadence-defining contract")
        self.account.contracts.add(name: cadenceContractName, code: cadenceCode, name, symbol, evmContractAddress)
        emit BridgeDefiningContractDeployed(
            contractName: cadenceContractName,
            assetName: name,
            symbol: symbol,
            isERC721: isERC721,
            evmContractAddress: evmContractAddress
        )
    }
}
