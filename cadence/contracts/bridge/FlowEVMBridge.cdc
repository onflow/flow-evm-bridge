import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "FlowToken"

import "EVM"

import "ICrossVM"
import "CrossVMAsset"
import "CrossVMNFT"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"
import "FlowEVMBridgeNFTEscrow"
import "FlowEVMBridgeTemplates"

/// The FlowEVMBridge contract is the main entrypoint for bridging NFT & FT assets between Flow & FlowEVM.
///
/// Before bridging, be sure to onboard the asset type which will configure the bridge to handle the asset. From there,
/// the asset can be bridged between VMs via the COA as the entrypoint.
///
/// See also:
/// - Code in context: https://github.com/onflow/flow-evm-bridge
/// - FLIP #237: https://github.com/onflow/flips/pull/233
///
access(all) contract FlowEVMBridge {

    /* --- Events --- */
    //
    /// Denotes a Locker contract was deployed to the bridge account
    access(all) event BridgeLockerContractDeployed(lockedType: Type, contractName: String, evmContractAddress: String)
    /// Denotes a defining contract was deployed to the bridge accountcode
    access(all) event BridgeDefiningContractDeployed(
        contractName: String,
        assetName: String,
        symbol: String,
        isERC721: Bool,
        evmContractAddress: String
    )
    /// Broadcasts an NFT was bridged from Flow to EVM
    access(all) event BridgedNFTToEVM(
        type: Type,
        id: UInt64,
        evmID: UInt256,
        to: String,
        evmContractAddress: String,
        bridgeAddress: Address
    )
    /// Broadcasts an NFT was bridged from EVM to Flow
    access(all) event BridgedNFTFromEVM(type: Type,
        id: UInt64,
        evmID: UInt256,
        caller: String,
        evmContractAddress: String,
        bridgeAddress: Address
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
            FlowEVMBridgeUtils.validateFee(&tollFee, onboarding: true): "Invalid fee paid"
            self.typeRequiresOnboarding(type) == true: "Onboarding is not needed for this type"
            FlowEVMBridgeUtils.isFlowNative(type: type): "Only Flow-native assets can be onboarded by Type"
        }
        FlowEVMBridgeUtils.depositTollFee(<-tollFee)
        let erc721Address = self.deployEVMContract(forAssetType: type)
        FlowEVMBridgeNFTEscrow.initializeEscrow(forType: type, erc721Address: erc721Address)
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
            FlowEVMBridgeUtils.validateFee(&tollFee, onboarding: true): "Invalid fee paid"
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
    access(contract) fun bridgeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @{FungibleToken.Vault}) {
        pre {
            FlowEVMBridgeUtils.validateFee(&tollFee, onboarding: false): "Invalid fee paid"
            !token.isInstance(Type<@{FungibleToken.Vault}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(token.getType()) == false: "NFT must first be onboarded"
        }
        let tokenType = token.getType()
        let tokenID = CrossVMNFT.getEVMID(from: &token) ?? UInt256(token.getID())
        // Grab the URI from the NFT
        var uri: String = ""
        if let display = token.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display? {
            uri = display.thumbnail.uri()
        }
        FlowEVMBridgeUtils.depositTollFee(<-tollFee)
        FlowEVMBridgeNFTEscrow.lockNFT(<-token)

        // Does the bridge control the EVM contract associated with this type?
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: tokenType)
            ?? panic("No EVMAddress found for token type")
        let factoryResponse = EVM.decodeABI(
                types: [Type<Bool>()],
                data: FlowEVMBridgeUtils.call(
                    signature: "isFactoryDeployed(address)",
                    targetEVMAddress: FlowEVMBridgeUtils.bridgeFactoryEVMAddress,
                    args: [associatedAddress],
                    gasLimit: 12000000,
                    value: 0.0
                ),
            ) as! [AnyStruct]
        assert(factoryResponse.length == 1, message: "Invalid response length")
        let isFactoryDeployed = factoryResponse[0] as! Bool
        if isFactoryDeployed {
            // Check if the ERC721 exists
            let existsResponse = EVM.decodeABI(
                    types: [Type<Bool>()],
                    data: FlowEVMBridgeUtils.call(
                        signature: "exists(uint256)",
                        targetEVMAddress: associatedAddress,
                        args: [tokenID],
                        gasLimit: 12000000,
                        value: 0.0
                    ),
                ) as! [AnyStruct]
            assert(existsResponse.length == 1, message: "Invalid response length")
            let exists = existsResponse[0] as! Bool
            if exists == true {
                // if so transfer
                FlowEVMBridgeUtils.call(
                    signature: "safeTransferFrom(address,address,uint256)",
                    targetEVMAddress: associatedAddress,
                    args: [self.getBridgeCOAEVMAddress(), to, tokenID],
                    gasLimit: 15000000,
                    value: 0.0
                )
            } else {
                // Otherwise mint
                FlowEVMBridgeUtils.call(
                    signature: "safeMint(address,uint256,string)",
                    targetEVMAddress: associatedAddress,
                    args: [to, tokenID, uri],
                    gasLimit: 15000000,
                    value: 0.0
                )
            }
        } else {
            FlowEVMBridgeUtils.call(
                signature: "safeTransferFrom(address,address,uint256)",
                targetEVMAddress: associatedAddress,
                args: [self.getBridgeCOAEVMAddress(), to, tokenID],
                gasLimit: 15000000,
                value: 0.0
            )
        }
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
    access(contract) fun bridgeNFTFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @{FungibleToken.Vault}
    ): @{NonFungibleToken.NFT} {
        pre {
            FlowEVMBridgeUtils.validateFee(&tollFee, onboarding: false): "Invalid fee paid"
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
        if FlowEVMBridgeUtils.isValidFlowAsset(type: type){
            // TODO: FT validation
            return !FlowEVMBridgeNFTEscrow.isInitialized(forType: type)
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
    // access(all) view fun borrowLockerContract(forType: Type): &IEVMBridgeNFTLocker? {
    //     if let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: forType) {
    //         return self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName)
    //     }
    //     return nil
    // }

    /// Entrypoint for the bridging between VMs using this bridge contract
    ///
    access(all) resource Accessor : EVM.BridgeAccessor {
        access(EVM.Bridge)
        fun depositNFT(nft: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, fee: @{FungibleToken.Vault}) {
            FlowEVMBridge.bridgeNFTToEVM(token: <-nft, to: to, tollFee: <-fee)
        }
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
        // if self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName) == nil {
        //     self.deployLockerContract(forType: token.getType())
        // }
        panic("TODO: Remove this panic")
        // let lockerContract: &IEVMBridgeNFTLocker = self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName)
        //     ?? panic("Problem locating Locker contract for token type: ".concat(token.getType().identifier))
        // lockerContract.bridgeNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
        // FlowEVMBridgeUtils.depositTollFee(<-tollFee)
        // let tokenType = token.getType()
        // FlowEVMBridgeNFTEscrow.lockNFT(<-token)
        // self.executeNFTBridgeFromEVM(type: tokenType, to: to))
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
        assert(decodedResponse.length == 1, message: "Invalid response length")
        let identifier: String = decodedResponse[0] as! String
        let lockedType: Type = CompositeType(identifier) ?? panic("Invalid identifier returned from EVM contract")
        let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: lockedType)
            ?? panic("Could not derive locker contract name for token type: ".concat(lockedType.identifier))
        panic("TODO: Remove this panic")
        // let lockerContract: &IEVMBridgeNFTLocker = self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName)
        //     ?? panic("Problem configuring Locker contract for token type: ".concat(lockedType.identifier))
        // return <- lockerContract.bridgeNFTFromEVM(
        //     caller: caller,
        //     calldata: calldata,
        //     id: id,
        //     evmContractAddress: evmContractAddress,
        //     tollFee: <-tollFee
        // )
    }

    /// Attempts to retrieve the bridging contract for NFT, returning true if it conforms to
    /// CrossVMAsset.BridgeableAsset and returns a reference to &IFlowEVMNFTBridge contract interface as its default
    /// bridge contract
    ///
    // access(self) fun tryNFTPassthrough(token: &{NonFungibleToken.NFT}): Bool {
    //     if let bridgeableAsset: &{CrossVMAsset.BridgeableAsset} = token as? &{CrossVMAsset.BridgeableAsset} {
    //         if let bridgeContract = bridgeableAsset.borrowDefaultBridgeContract() as? &IFlowEVMNFTBridge {
    //             return true
    //         }
    //     }
    //     return false
    // }

    /// Passes through the bridge call to the default bridge contract of the NFT according to
    /// CrossVMAsset.BridgeableAsset and &IFlowEVMNFTBridge interfaces
    ///
    // access(self) fun passthroughNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @{FungibleToken.Vault}) {
    //     // This call passes the bridge request, but the tollFee may not be sufficient to cover the request as
    //     // that value is not defined by this bridge contract
    //     let tokenRef: &{NonFungibleToken.NFT} = &token
    //     let bridgeableAsset = tokenRef as! &{CrossVMAsset.BridgeableAsset}
    //     let bridgeContract = bridgeableAsset.borrowDefaultBridgeContract() as! &IFlowEVMNFTBridge
    //     bridgeContract.bridgeNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
    // }

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
        // let bridgedNFTContract = self.account.contracts.borrow<&IFlowEVMNFTBridge>(name: contractName)
        //     ?? panic("Could not borrow the bridged NFT contract for this EVM-native NFT")
        panic("TODO: Remove this panic for evm-native path")
        // return <- bridgedNFTContract.bridgeNFTFromEVM(
        //     caller: caller,
        //     calldata: calldata,
        //     id: id,
        //     evmContractAddress: evmContractAddress,
        //     tollFee: <-tollFee
        // )
    }

    /// Helper for deploying templated Locker contract supporting Flow-native asset bridging to EVM
    /// Deploys either NFT or FT locker depending on the asset type
    ///
    /// @param forType: The Cadence Type of the asset
    ///
    // access(self) fun deployLockerContract(forType: Type) {
    //     let evmContractAddress: EVM.EVMAddress = self.deployEVMContract(forAssetType: forType)

    //     let code: [UInt8] = FlowEVMBridgeTemplates.getLockerContractCode(forType: forType)
    //         ?? panic("Could not retrieve code for given asset type: ".concat(forType.identifier))
    //     let name: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: forType)
    //         ?? panic("Could not derive locker contract name for token type: ".concat(forType.identifier))
    //     let contractAddress: Address = FlowEVMBridgeUtils.getContractAddress(fromType: forType)
    //         ?? panic("Could not derive locker contract address for token type: ".concat(forType.identifier))
    //     self.account.contracts.add(name: name, code: code, forType, contractAddress, evmContractAddress)

    //     emit BridgeLockerContractDeployed(
    //         lockedType: forType,
    //         contractName: name,
    //         evmContractAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: evmContractAddress)
    //     )
    // }

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
            args: [name, "BRDG", cadenceAddressStr, identifier], // TODO: Decide on and update symbol
            gasLimit: 15000000,
            value: 0.0
        )
        let decodedResponse: [AnyStruct] = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: response)
        assert(decodedResponse.length == 1, message: "Invalid response length")
        let erc721Address: EVM.EVMAddress = decodedResponse[0] as! EVM.EVMAddress
        FlowEVMBridgeConfig.associateType(forNFTType, with: erc721Address)
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
            evmContractAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: evmContractAddress)
        )
    }

    init(evmBridgeRouterAddress: Address) {
        self.account.storage.save(<-create Accessor(), to: /storage/flowEVMBridgeAccessor)
        let accessorCap = self.account.capabilities.storage.issue<auth(EVM.Bridge) &{EVM.BridgeAccessor}>(
                FlowEVMBridgeConfig.bridgeAccessorStoragePath
            )
        self.account.inbox.publish(accessorCap, name: "EVMBridgeAccessor", recipient: evmBridgeRouterAddress)
    }
}
