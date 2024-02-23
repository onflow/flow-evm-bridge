import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "FlowToken"

import "EVM"

import "ICrossVM"
import "IEVMBridgeNFTMinter"
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
    /// Emitted any time a new asset type is onboarded to the bridge
    access(all) event Onboarded(type: Type, cadenceContractAddress: Address, evmContractAddress: String)
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
        evmContractAddress: String
    )
    /// Broadcasts an NFT was bridged from EVM to Flow
    access(all) event BridgedNFTFromEVM(
        type: Type,
        id: UInt64,
        evmID: UInt256,
        caller: String,
        evmContractAddress: String
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
        emit Onboarded(
            type: type,
            cadenceContractAddress: FlowEVMBridgeUtils.getContractAddress(fromType: type)!,
            evmContractAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: erc721Address)
        )
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
        let tokenID = token.getID()
        let evmID = CrossVMNFT.getEVMID(from: &token) ?? UInt256(token.getID())
        // TODO: Enhance metadata handling on briding - URI should provide serialized JSON metadata when requested
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
        let isFactoryDeployed = FlowEVMBridgeUtils.isEVMContractBridgeOwned(evmContractAddress: associatedAddress)
        // Controlled by the bridge - mint or transfer based on existence
        if isFactoryDeployed {
            // Check if the ERC721 exists
            let existsResponse = EVM.decodeABI(
                    types: [Type<Bool>()],
                    data: FlowEVMBridgeUtils.call(
                        signature: "exists(uint256)",
                        targetEVMAddress: associatedAddress,
                        args: [evmID],
                        gasLimit: 12000000,
                        value: 0.0
                    ),
                ) as! [AnyStruct]
            assert(existsResponse.length == 1, message: "Invalid response length")
            let exists = existsResponse[0] as! Bool
            if exists {
                // if so transfer
                FlowEVMBridgeUtils.call(
                    signature: "safeTransferFrom(address,address,uint256)",
                    targetEVMAddress: associatedAddress,
                    args: [self.getBridgeCOAEVMAddress(), to, evmID],
                    gasLimit: 15000000,
                    value: 0.0
                )
            } else {
                // Otherwise mint
                FlowEVMBridgeUtils.call(
                    signature: "safeMint(address,uint256,string)",
                    targetEVMAddress: associatedAddress,
                    args: [to, evmID, uri],
                    gasLimit: 15000000,
                    value: 0.0
                )
            }
        } else {
            // Not bridge-controlled, transfer existing ownership
            FlowEVMBridgeUtils.call(
                signature: "safeTransferFrom(address,address,uint256)",
                targetEVMAddress: associatedAddress,
                args: [self.getBridgeCOAEVMAddress(), to, evmID],
                gasLimit: 15000000,
                value: 0.0
            )
        }
        emit BridgedNFTToEVM(
            type: tokenType,
            id: tokenID,
            evmID: evmID,
            to: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: to),
            evmContractAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address:associatedAddress)
        )
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
        type: Type,
        id: UInt256,
        tollFee: @{FungibleToken.Vault}
    ): @{NonFungibleToken.NFT} {
        pre {
            FlowEVMBridgeUtils.validateFee(&tollFee, onboarding: false): "Invalid fee paid"
            !type.isSubtype(of: Type<@{FungibleToken.Vault}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(type) == false: "NFT must first be onboarded"
        }
        FlowEVMBridgeUtils.depositTollFee(<-tollFee)
        // Get the EVMAddress of the ERC721 contract associated with the type
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
            ?? panic("No EVMAddress found for token type")
        
        // Ensure caller is current NFT owner or approved
        let isAuthorized: Bool = FlowEVMBridgeUtils.isOwnerOrApproved(
            ofNFT: id,
            owner: caller.address(),
            evmContractAddress: associatedAddress
        )
        assert(isAuthorized, message: "Caller is not the owner of or approved for requested NFT")

        // Execute the transfer from the calling owner to the bridge COA
        caller.call(
            to: associatedAddress,
            data: FlowEVMBridgeUtils.encodeABIWithSignature(
                "safeTransferFrom(address,address,uint256)",
                [caller.address(), self.getBridgeCOAEVMAddress(), id]
            ), gasLimit: 15000000,
            value: EVM.Balance(flow: 0.0)
        )
        // NFT is locked - unlock
        if let cadenceID = FlowEVMBridgeNFTEscrow.getLockedCadenceID(type: type, evmID: id) {
            return <-FlowEVMBridgeNFTEscrow.unlockNFT(type: type, id: cadenceID)
        }
        // NFT is not locked but has been onboarded - mint
        let contractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: type)!
        if self.account.address == contractAddress {
            let contractName = FlowEVMBridgeUtils.getContractName(fromType: type)!
            let nftContract = self.account.contracts.borrow<&IEVMBridgeNFTMinter>(name: contractName)!
            let uri = FlowEVMBridgeUtils.getTokenURI(evmContractAddress: associatedAddress, id: id)
            return <-nftContract.mintNFT(id: id, tokenURI: uri)
        }
        // Should not get to this point assuming Type was onboarded
        panic("Unexpected error bridging NFT from EVM")
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

    /// Retrieves the EVM address of the contract related to the given type, assuming it has been onboarded.
    ///
    /// @param type: The Cadence Type of the asset
    ///
    /// @returns The EVMAddress of the contract defining the asset
    ///
    access(all) fun getAssetEVMContractAddress(type: Type): EVM.EVMAddress? {
        return FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
    }

    /// Returns whether an asset needs to be onboarded to the bridge
    ///
    /// @param type: The Cadence Type of the asset
    ///
    /// @returns Whether the asset needs to be onboarded
    ///
    access(all) view fun typeRequiresOnboarding(_ type: Type): Bool? {
        if FlowEVMBridgeUtils.isValidFlowAsset(type: type) {
            // TODO: FT validation
            return !FlowEVMBridgeNFTEscrow.isInitialized(forType: type)
        }
        return nil
    }

    /// Returns whether an EVM-native asset needs to be onboarded to the bridge
    ///
    /// @param address: The EVMAddress of the asset
    ///
    /// @returns Whether the asset needs to be onboarded, nil if the defined asset is not supported by this bridge
    ///
    access(all) fun evmAddressRequiresOnboarding(_ address: EVM.EVMAddress): Bool? {
        // If the address was deployed by the bridge or a Cadence contract has been deployed to define the
        // corresponding NFT, it's already been onboarded
        let cadenceContractName = FlowEVMBridgeUtils.deriveBridgedNFTContractName(from: address)
        if FlowEVMBridgeUtils.isEVMContractBridgeOwned(evmContractAddress: address) ||
            self.account.contracts.get(name: cadenceContractName) != nil {
            return false
        }
        // Dealing with EVM-native asset, check if it's NFT or FT exclusively
        if FlowEVMBridgeUtils.isValidEVMAsset(evmContractAddress: address) {
            return true
        }
        return nil
    }

    /// Entrypoint for the bridging between VMs using this bridge contract
    ///
    access(all) resource Accessor : EVM.BridgeAccessor {
        /// Endpoint enabling NFT bridging to EVM
        ///
        access(EVM.Bridge)
        fun depositNFT(nft: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, fee: @{FungibleToken.Vault}) {
            FlowEVMBridge.bridgeNFTToEVM(token: <-nft, to: to, tollFee: <-fee)
        }

        /// Endpoint enabling NFT from EVM
        ///
        access(EVM.Bridge)
        fun withdrawNFT(
            caller: &EVM.BridgedAccount,
            type: Type,
            id: UInt256,
            fee: @{FungibleToken.Vault}
        ): @{NonFungibleToken.NFT} {
            return <-FlowEVMBridge.bridgeNFTFromEVM(caller: caller, type: type, id: id, tollFee: <-fee)
        }
    }

    /**************************
        Internal Helpers
    ***************************/

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

    /// Deploys templated ERC721 contract supporting EVM-native asset bridging to Flow
    ///
    /// @param forNFTType: The Cadence Type of the NFT
    ///
    /// @returns The EVMAddress of the deployed contract
    ///
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
    /// @param evmContractAddress: The EVMAddress currently defining the asset to be bridged
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
        // Create Accessor & publish private Capability for use by the EVM contract
        self.account.storage.save(<-create Accessor(), to: /storage/flowEVMBridgeAccessor)
        let accessorCap = self.account.capabilities.storage.issue<auth(EVM.Bridge) &{EVM.BridgeAccessor}>(
                FlowEVMBridgeConfig.bridgeAccessorStoragePath
            )
        self.account.inbox.publish(accessorCap, name: "EVMBridgeAccessor", recipient: evmBridgeRouterAddress)
    }
}
