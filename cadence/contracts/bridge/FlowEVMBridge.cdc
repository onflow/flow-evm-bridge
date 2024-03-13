import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "FlowToken"

import "EVM"

import "BridgePermissions"
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
access(all)
contract FlowEVMBridge {

    /*************
        Events
    **************/

    /// Emitted any time a new asset type is onboarded to the bridge
    access(all)
    event Onboarded(type: Type, cadenceContractAddress: Address, evmContractAddress: String)
    /// Denotes a defining contract was deployed to the bridge accountcode
    access(all)
    event BridgeDefiningContractDeployed(
        contractName: String,
        assetName: String,
        symbol: String,
        isERC721: Bool,
        evmContractAddress: String
    )
    /// Broadcasts an NFT was bridged from Cadence to EVM
    access(all)
    event BridgedNFTToEVM(
        type: Type,
        id: UInt64,
        evmID: UInt256,
        to: String,
        evmContractAddress: String
    )
    /// Broadcasts an NFT was bridged from EVM to Cadence
    access(all)
    event BridgedNFTFromEVM(
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
    /// in a third-party contract. Attempting to onboard a bridge-defined asset will result in an error as the asset has
    /// already been onboarded to the bridge.
    ///
    /// @param type: The Cadence Type of the NFT to be onboarded
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun onboardByType(_ type: Type, feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}) {
        pre {
            feeProvider.isAvailableToWithdraw(amount: FlowEVMBridgeConfig.onboardFee):
                "Insufficient fee available via feeProvider"
            self.typeRequiresOnboarding(type) == true: "Onboarding is not needed for this type"
            FlowEVMBridgeUtils.isCadenceNative(type: type): "Only Cadence-native assets can be onboarded by Type"
        }
        // Ensure the project has not opted out of bridge support
        assert(
            FlowEVMBridgeUtils.typeAllowsBridging(type),
            message: "This type is not supported as defined by the project's development team"
        )
        // Withdraw from feeProvider and deposit to self
        let feeVault <-feeProvider.withdraw(amount: FlowEVMBridgeConfig.onboardFee) as! @FlowToken.Vault
        FlowEVMBridgeUtils.deposit(<-feeVault)
        // Deploy an EVM defining contract via the FlowBridgeFactory.sol contract
        let erc721Address = self.deployEVMContract(forAssetType: type)
        // Initialize bridge escrow for the asset
        FlowEVMBridgeNFTEscrow.initializeEscrow(forType: type, erc721Address: erc721Address)

        emit Onboarded(
            type: type,
            cadenceContractAddress: FlowEVMBridgeUtils.getContractAddress(fromType: type)!,
            evmContractAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: erc721Address)
        )
    }

    /// Onboards a given EVM contract to the bridge. Since we're onboarding by EVM Address, the asset must be defined in
    /// a third-party EVM contract. Attempting to onboard a bridge-defined asset will result in an error as onboarding
    /// is not required.
    ///
    /// @param address: The EVMAddress of the ERC721 or ERC20 to be onboarded
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun onboardByEVMAddress(
        _ address: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            feeProvider.isAvailableToWithdraw(amount: FlowEVMBridgeConfig.onboardFee):
                "Insufficient fee available via feeProvider"
        }
        // Ensure the project has not opted out of bridge support
        assert(
            FlowEVMBridgeUtils.evmAddressAllowsBridging(address),
            message: "This contract is not supported as defined by the project's development team"
        )
        assert(
            self.evmAddressRequiresOnboarding(address) == true,
            message: "Onboarding is not needed for this contract"
        )
        // Withdraw from feeProvider and deposit to self
        let feeVault <-feeProvider.withdraw(amount: FlowEVMBridgeConfig.onboardFee) as! @FlowToken.Vault
        FlowEVMBridgeUtils.deposit(<-feeVault)
        // Deploy a defining Cadence contract to the bridge account
        self.deployDefiningContract(evmContractAddress: address)
    }

    /// Public entrypoint to bridge NFTs from Cadence to EVM.
    ///
    /// @param token: The NFT to be bridged
    /// @param to: The NFT recipient in FlowEVM
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun bridgeNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            !token.isInstance(Type<@{FungibleToken.Vault}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(token.getType()) == false: "NFT must first be onboarded"
        }
        let tokenType = token.getType()
        let tokenID = token.id
        let evmID = CrossVMNFT.getEVMID(from: &token as &{NonFungibleToken.NFT}) ?? UInt256(token.id)
        // Grab the URI from the NFT if available
        var uri: String = ""
        if let metadata = token.resolveView(Type<CrossVMNFT.EVMBridgedMetadata>()) as! CrossVMNFT.EVMBridgedMetadata? {
            uri = metadata.uri.uri()
        }

        // Lock the NFT & calculate the storage used by the NFT
        let storageUsed = FlowEVMBridgeNFTEscrow.lockNFT(<-token)
        // Calculate the bridge fee on current rates
        let feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(used: storageUsed, includeBase: true)
        assert(
            feeProvider.isAvailableToWithdraw(amount: feeAmount),
            message: "Fee provider does not have balance to cover the bridge fee of".concat(feeAmount.toString())
        )
        // Withdraw from feeProvider and deposit to self
        let feeVault <-feeProvider.withdraw(amount: feeAmount) as! @FlowToken.Vault
        FlowEVMBridgeUtils.deposit(<-feeVault)

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
                    ).data,
                )
            assert(existsResponse.length == 1, message: "Invalid response length")
            let exists = existsResponse[0] as! Bool
            if exists {
                // if so transfer
                let callResult: EVM.Result = FlowEVMBridgeUtils.call(
                    signature: "safeTransferFrom(address,address,uint256)",
                    targetEVMAddress: associatedAddress,
                    args: [self.getBridgeCOAEVMAddress(), to, evmID],
                    gasLimit: 15000000,
                    value: 0.0
                )
                assert(callResult.status == EVM.Status.successful, message: "Tranfer to bridge recipient failed")
            } else {
                // Otherwise mint
                let callResult: EVM.Result = FlowEVMBridgeUtils.call(
                    signature: "safeMint(address,uint256,string)",
                    targetEVMAddress: associatedAddress,
                    args: [to, evmID, uri],
                    gasLimit: 15000000,
                    value: 0.0
                )
                assert(callResult.status == EVM.Status.successful, message: "Tranfer to bridge recipient failed")
            }
        } else {
            // Not bridge-controlled, transfer existing ownership
            let callResult: EVM.Result = FlowEVMBridgeUtils.call(
                signature: "safeTransferFrom(address,address,uint256)",
                targetEVMAddress: associatedAddress,
                args: [self.getBridgeCOAEVMAddress(), to, evmID],
                gasLimit: 15000000,
                value: 0.0
            )
            assert(callResult.status == EVM.Status.successful, message: "Tranfer to bridge recipient failed")
        }
        emit BridgedNFTToEVM(
            type: tokenType,
            id: tokenID,
            evmID: evmID,
            to: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: to),
            evmContractAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address:associatedAddress)
        )
    }

    /// Public entrypoint to bridge NFTs from EVM to Cadence
    ///
    /// @param caller: The caller executing the bridge - must be passed to check EVM state pre- & post-call in scope
    /// @param calldata: Caller-provided approve() call, enabling contract COA to operate on NFT in EVM contract
    /// @param id: The NFT ID to bridged
    /// @param evmContractAddress: Address of the EVM address defining the NFT being bridged - also call target
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    /// @returns The bridged NFT
    ///
    access(all)
    fun bridgeNFTFromEVM(
        caller: auth(EVM.Call) &EVM.CadenceOwnedAccount,
        type: Type,
        id: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ): @{NonFungibleToken.NFT} {
        pre {
            feeProvider.isAvailableToWithdraw(amount: FlowEVMBridgeUtils.calculateBridgeFee(used: 0, includeBase: true)):
                "Insufficient fee paid"
            !type.isSubtype(of: Type<@{FungibleToken.Vault}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(type) == false: "NFT must first be onboarded"
        }
        // Withdraw from feeProvider and deposit to self
        let feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(used: 0, includeBase: true)
        let feeVault <-feeProvider.withdraw(amount: feeAmount) as! @FlowToken.Vault
        FlowEVMBridgeUtils.deposit(<-feeVault)

        // Get the EVMAddress of the ERC721 contract associated with the type
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
            ?? panic("No EVMAddress found for token type")
        
        // Ensure the caller is either the current owner or approved for the NFT
        let isAuthorized: Bool = FlowEVMBridgeUtils.isOwnerOrApproved(
            ofNFT: id,
            owner: caller.address(),
            evmContractAddress: associatedAddress
        )
        assert(isAuthorized, message: "Caller is not the owner of or approved for requested NFT")

        // Execute the transfer from the calling owner to the bridge's COA, escrowing the NFT in EVM
        caller.call(
            to: associatedAddress,
            data: EVM.encodeABIWithSignature(
                "safeTransferFrom(address,address,uint256)",
                [caller.address(), self.getBridgeCOAEVMAddress(), id]
            ), gasLimit: 15000000,
            value: EVM.Balance(attoflow: 0)
        )

        // Ensure the bridge is now the owner of the NFT after the preceding transfer
        let isEscrowed: Bool = FlowEVMBridgeUtils.isOwner(
            ofNFT: id,
            owner: self.getBridgeCOAEVMAddress(),
            evmContractAddress: associatedAddress
        )
        assert(isEscrowed, message: "Transfer to bridge COA failed - cannot bridge NFT without bridge escrow")
        // If the NFT is currently lock, unlock and return
        if let cadenceID = FlowEVMBridgeNFTEscrow.getLockedCadenceID(type: type, evmID: id) {
            emit BridgedNFTFromEVM(
                type: type,
                id: cadenceID,
                evmID: id,
                caller: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: caller.address()),
                evmContractAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: associatedAddress)
            )
            return <-FlowEVMBridgeNFTEscrow.unlockNFT(type: type, id: cadenceID)
        }
        // Otherwise, we expect the NFT to be minted in Cadence
        let contractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: type)!
        assert(self.account.address == contractAddress, message: "Unexpected error bridging NFT from EVM")

        let contractName = FlowEVMBridgeUtils.getContractName(fromType: type)!
        let nftContract = getAccount(contractAddress).contracts.borrow<&{IEVMBridgeNFTMinter}>(name: contractName)!
        let uri = FlowEVMBridgeUtils.getTokenURI(evmContractAddress: associatedAddress, id: id)
        let nft <- nftContract.mintNFT(id: id, tokenURI: uri)
        emit BridgedNFTFromEVM(
                type: type,
                id: nft.id,
                evmID: id,
                caller: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: caller.address()),
                evmContractAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: associatedAddress)
            )
        return <-nft
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
    access(all)
    view fun getBridgeCOAEVMAddress(): EVM.EVMAddress {
        return FlowEVMBridgeUtils.borrowCOA().address()
    }

    /// Retrieves the EVM address of the contract related to the given type, assuming it has been onboarded.
    ///
    /// @param type: The Cadence Type of the asset
    ///
    /// @returns The EVMAddress of the contract defining the asset
    ///
    access(all)
    fun getAssetEVMContractAddress(type: Type): EVM.EVMAddress? {
        return FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
    }

    /// Returns whether an asset needs to be onboarded to the bridge
    ///
    /// @param type: The Cadence Type of the asset
    ///
    /// @returns Whether the asset needs to be onboarded
    ///
    access(all)
    view fun typeRequiresOnboarding(_ type: Type): Bool? {
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
    access(all)
    fun evmAddressRequiresOnboarding(_ address: EVM.EVMAddress): Bool? {
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

    /**************************
        Internal Helpers
    ***************************/

    /// Deploys templated EVM contract via Solidity Factory contract supporting bridging of a given asset type
    ///
    /// @param forAssetType: The Cadence Type of the asset
    ///
    /// @returns The EVMAddress of the deployed contract
    ///
    access(self)
    fun deployEVMContract(forAssetType: Type): EVM.EVMAddress {
        if forAssetType.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) {
            return self.deployERC721(forAssetType)
        } else if forAssetType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            // TODO
            // return self.deployERC20(name: forAssetType.identifier)
        }
        panic("Unsupported asset type: ".concat(forAssetType.identifier))
    }

    /// Deploys templated ERC721 contract supporting EVM-native asset bridging to Cadence
    ///
    /// @param forNFTType: The Cadence Type of the NFT
    ///
    /// @returns The EVMAddress of the deployed contract
    ///
    access(self)
    fun deployERC721(_ forNFTType: Type): EVM.EVMAddress {
        // Retrieve the Cadence type's defining contract name, address, & its identifier
        var name = FlowEVMBridgeUtils.getContractName(fromType: forNFTType)
            ?? panic("Could not contract name from type: ".concat(forNFTType.identifier))
        let identifier = forNFTType.identifier
        let cadenceAddress = FlowEVMBridgeUtils.getContractAddress(fromType: forNFTType)
            ?? panic("Could not derive contract address for token type: ".concat(identifier))
        // Assign a default symbol
        var symbol = "BRDG"
        // Borrow the ViewResolver to attempt to resolve the EVMBridgedMetadata view
        let viewResolver = getAccount(cadenceAddress).contracts.borrow<&{ViewResolver}>(name: name)!
        var contractURI = ""
        if let bridgedMetadata = viewResolver.resolveContractView(
                resourceType: forNFTType,
                viewType: Type<CrossVMNFT.EVMBridgedMetadata>()
            ) as! CrossVMNFT.EVMBridgedMetadata? {
            name = bridgedMetadata.name
            symbol = bridgedMetadata.symbol
            contractURI = bridgedMetadata.uri.uri()
        }

        // Call to the factory contract to deploy an ERC721
        let callResult: EVM.Result = FlowEVMBridgeUtils.call(
            signature: "deployERC721(string,string,string,string,string)",
            targetEVMAddress: FlowEVMBridgeUtils.bridgeFactoryEVMAddress,
            args: [name, symbol, cadenceAddress.toString(), identifier, contractURI], // TODO: Decide on and update symbol
            gasLimit: 15000000,
            value: 0.0
        )
        assert(callResult.status == EVM.Status.successful, message: "Contract deployment failed")
        let decodedResult: [AnyStruct] = EVM.decodeABI(types: [Type<EVM.EVMAddress>()], data: callResult.data)
        assert(decodedResult.length == 1, message: "Invalid response length")

        // Associate the deployed contract with the given type & return the deployed address
        let erc721Address = decodedResult[0] as! EVM.EVMAddress
        FlowEVMBridgeConfig.associateType(forNFTType, with: erc721Address)
        return erc721Address
    }

    /// Helper for deploying templated defining contract supporting EVM-native asset bridging to Cadence
    /// Deploys either NFT or FT contract depending on the provided type
    ///
    /// @param evmContractAddress: The EVMAddress currently defining the asset to be bridged
    ///
    access(self)
    fun deployDefiningContract(evmContractAddress: EVM.EVMAddress) {
        // Deploy the Cadence contract defining the asset
        // Treat as NFT if ERC721, otherwise FT
        let name: String = FlowEVMBridgeUtils.getName(evmContractAddress: evmContractAddress)
        let symbol: String = FlowEVMBridgeUtils.getSymbol(evmContractAddress: evmContractAddress)

        // Derive contract name
        let isERC721: Bool = FlowEVMBridgeUtils.isEVMNFT(evmContractAddress: evmContractAddress)
        let cadenceContractName: String = FlowEVMBridgeUtils.deriveBridgedNFTContractName(from: evmContractAddress)
        let contractURI = FlowEVMBridgeUtils.getContractURI(evmContractAddress: evmContractAddress)

        // Get Cadence code from template
        let cadenceCode: [UInt8] = FlowEVMBridgeTemplates.getBridgedAssetContractCode(
                evmContractAddress: evmContractAddress,
                isERC721: isERC721
            ) ?? panic("Problem retrieving code for Cadence-defining contract")
        self.account.contracts.add(name: cadenceContractName, code: cadenceCode, name, symbol, evmContractAddress, contractURI)

        emit BridgeDefiningContractDeployed(
            contractName: cadenceContractName,
            assetName: name,
            symbol: symbol,
            isERC721: isERC721,
            evmContractAddress: FlowEVMBridgeUtils.getEVMAddressAsHexString(address: evmContractAddress)
        )
    }
}
