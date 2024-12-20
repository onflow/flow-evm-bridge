import "Burner"
import "FungibleToken"
import "FungibleTokenMetadataViews"
import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

import "EVM"

import "IBridgePermissions"
import "ICrossVM"
import "IEVMBridgeNFTMinter"
import "IEVMBridgeTokenMinter"
import "IFlowEVMNFTBridge"
import "IFlowEVMTokenBridge"
import "CrossVMNFT"
import "CrossVMToken"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeUtils"
import "FlowEVMBridgeNFTEscrow"
import "FlowEVMBridgeTokenEscrow"
import "FlowEVMBridgeTemplates"
import "SerializeMetadata"

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
contract FlowEVMBridge : IFlowEVMNFTBridge, IFlowEVMTokenBridge {

    /*************
        Events
    **************/

    /// Emitted any time a new asset type is onboarded to the bridge
    access(all)
    event Onboarded(type: String, cadenceContractAddress: Address, evmContractAddress: String)
    /// Denotes a defining contract was deployed to the bridge account
    access(all)
    event BridgeDefiningContractDeployed(
        contractName: String,
        assetName: String,
        symbol: String,
        isERC721: Bool,
        evmContractAddress: String
    )

    /**************************
        Public Onboarding
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
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !FlowEVMBridgeConfig.isCadenceTypeBlocked(type):
                "This Cadence Type ".concat(type.identifier).concat(" is currently blocked from being onboarded")
            self.typeRequiresOnboarding(type) == true: "Onboarding is not needed for this type"
            FlowEVMBridgeUtils.typeAllowsBridging(type):
                "This type is not supported as defined by the project's development team"
            FlowEVMBridgeUtils.isCadenceNative(type: type): "Only Cadence-native assets can be onboarded by Type"
        }
        /* Provision fees */
        //
        // Withdraw from feeProvider and deposit to self
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: FlowEVMBridgeConfig.onboardFee)

        /* EVM setup */
        //
        // Deploy an EVM defining contract via the FlowBridgeFactory.sol contract
        let onboardingValues = self.deployEVMContract(forAssetType: type)

        /* Cadence escrow setup */
        //
        // Initialize bridge escrow for the asset based on its type
        if type.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) {
            FlowEVMBridgeNFTEscrow.initializeEscrow(
                forType: type,
                name: onboardingValues.name,
                symbol: onboardingValues.symbol,
                erc721Address: onboardingValues.evmContractAddress
            )
        } else if type.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            let createVaultFunction = FlowEVMBridgeUtils.getCreateEmptyVaultFunction(forType: type)
                ?? panic("Could not retrieve createEmptyVault function for the given type")
            let vault <-createVaultFunction(type)
            assert(
                vault.getType() == type,
                message: "Requested to onboard type=".concat(type.identifier).concat( "but contract returned type=").concat(vault.getType().identifier)
            )
            FlowEVMBridgeTokenEscrow.initializeEscrow(
                with: <-vault,
                name: onboardingValues.name,
                symbol: onboardingValues.symbol,
                decimals: onboardingValues.decimals!,
                evmTokenAddress: onboardingValues.evmContractAddress
            )
        } else {
            panic("Attempted to onboard unsupported type: ".concat(type.identifier))
        }

        /* Confirmation */
        //
        assert(
            FlowEVMBridgeNFTEscrow.isInitialized(forType: type) || FlowEVMBridgeTokenEscrow.isInitialized(forType: type),
            message: "Failed to initialize escrow for given type"
        )

        emit Onboarded(
            type: type.identifier,
            cadenceContractAddress: FlowEVMBridgeUtils.getContractAddress(fromType: type)!,
            evmContractAddress: onboardingValues.evmContractAddress.toString()
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
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !FlowEVMBridgeConfig.isEVMAddressBlocked(address):
                "This EVM contract ".concat(address.toString()).concat(" is currently blocked from being onboarded")
        }
        /* Validate the EVM contract */
        //
        // Ensure the project has not opted out of bridge support
        assert(
            FlowEVMBridgeUtils.evmAddressAllowsBridging(address),
            message: "This contract is not supported as defined by the project's development team"
        )
        assert(
            self.evmAddressRequiresOnboarding(address) == true,
            message: "Onboarding is not needed for this contract"
        )

        /* Provision fees */
        //
        // Withdraw fee from feeProvider and deposit
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: FlowEVMBridgeConfig.onboardFee)

        /* Setup Cadence-defining contract */
        //
        // Deploy a defining Cadence contract to the bridge account
        self.deployDefiningContract(evmContractAddress: address)
    }

    /*************************
        NFT Handling
    **************************/

    /// Public entrypoint to bridge NFTs from Cadence to EVM as ERC721.
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
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !token.isInstance(Type<@{FungibleToken.Vault}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(token.getType()) == false: "NFT must first be onboarded"
            FlowEVMBridgeConfig.isTypePaused(token.getType()) == false: "Bridging is currently paused for this NFT"
        }
        /* Gather identifying information */
        //
        let tokenType = token.getType()
        let tokenID = token.id
        let evmID = CrossVMNFT.getEVMID(from: &token as &{NonFungibleToken.NFT}) ?? UInt256(token.id)

        /* Metadata assignement */
        //
        // Grab the URI from the NFT if available
        var uri: String = ""
        // Default to project-specified URI
        if let metadata = token.resolveView(Type<MetadataViews.EVMBridgedMetadata>()) as! MetadataViews.EVMBridgedMetadata? {
            uri = metadata.uri.uri()
        } else {
            // Otherwise, serialize the NFT
            uri = SerializeMetadata.serializeNFTMetadataAsURI(&token as &{NonFungibleToken.NFT})
        }

        /* Secure NFT in escrow & deposit calculated fees */
        //
        // Lock the NFT & calculate the storage used by the NFT
        let storageUsed = FlowEVMBridgeNFTEscrow.lockNFT(<-token)
        // Calculate the bridge fee on current rates
        let feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: storageUsed)
        // Withdraw fee from feeProvider and deposit
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: feeAmount)

        /* Determine EVM handling */
        //
        // Does the bridge control the EVM contract associated with this type?
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: tokenType)
            ?? panic("No EVMAddress found for token type")
        let isFactoryDeployed = FlowEVMBridgeUtils.isEVMContractBridgeOwned(evmContractAddress: associatedAddress)

        /* Third-party controlled ERC721 handling */
        //
        // Not bridge-controlled, transfer existing ownership
        if !isFactoryDeployed {
            FlowEVMBridgeUtils.mustSafeTransferERC721(erc721Address: associatedAddress, to: to, id: evmID)
            return
        }

        /* Bridge-owned ERC721 handling */
        //
        // Check if the ERC721 exists in the EVM contract - determines if bridge mints or transfers
        let exists = FlowEVMBridgeUtils.erc721Exists(erc721Address: associatedAddress, id: evmID)
        if exists {
            // Transfer the existing NFT
            FlowEVMBridgeUtils.mustSafeTransferERC721(erc721Address: associatedAddress, to: to, id: evmID)

            // And update the URI to reflect current metadata
            FlowEVMBridgeUtils.mustUpdateTokenURI(erc721Address: associatedAddress, id: evmID, uri: uri)
        } else {
            // Otherwise mint with current URI
            FlowEVMBridgeUtils.mustSafeMintERC721(erc721Address: associatedAddress, to: to, id: evmID, uri: uri)
        }
    }

    /// Entrypoint to bridge ERC721 from EVM to Cadence as NonFungibleToken.NFT
    ///
    /// @param owner: The EVM address of the NFT owner. Current ownership and successful transfer (via
    ///     `protectedTransferCall`) is validated before the bridge request is executed.
    /// @param calldata: Caller-provided approve() call, enabling contract COA to operate on NFT in EVM contract
    /// @param id: The NFT ID to bridged
    /// @param evmContractAddress: Address of the EVM address defining the NFT being bridged - also call target
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    /// @param protectedTransferCall: A function that executes the transfer of the NFT from the named owner to the
    ///     bridge's COA. This function is expected to return a Result indicating the status of the transfer call.
    ///
    /// @returns The bridged NFT
    ///
    access(account)
    fun bridgeNFTFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        id: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (): EVM.Result
    ): @{NonFungibleToken.NFT} {
        pre {
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !type.isSubtype(of: Type<@{FungibleToken.Vault}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(type) == false: "NFT must first be onboarded"
            FlowEVMBridgeConfig.isTypePaused(type) == false: "Bridging is currently paused for this NFT"
        }
        /* Provision fee */
        //
        // Withdraw from feeProvider and deposit to self
        let feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: 0)
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: feeAmount)

        /* Execute escrow transfer */
        //
        // Get the EVMAddress of the ERC721 contract associated with the type
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
            ?? panic("No EVMAddress found for token type")
        // Execute the transfer call and make needed state assertions to confirm escrow from named owner
        FlowEVMBridgeUtils.mustEscrowERC721(
            owner: owner,
            id: id,
            erc721Address: associatedAddress,
            protectedTransferCall: protectedTransferCall
        )

        /* Gather identifying info */
        //
        // Derive the defining Cadence contract name & address & attempt to borrow it as IEVMBridgeNFTMinter
        let contractName = FlowEVMBridgeUtils.getContractName(fromType: type)!
        let contractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: type)!
        let nftContract = getAccount(contractAddress).contracts.borrow<&{IEVMBridgeNFTMinter}>(name: contractName)
        // Get the token URI from the ERC721 contract
        let uri = FlowEVMBridgeUtils.getTokenURI(evmContractAddress: associatedAddress, id: id)

        /* Unlock escrowed NFTs */
        //
        // If the NFT is currently locked, unlock and return
        if let cadenceID = FlowEVMBridgeNFTEscrow.getLockedCadenceID(type: type, evmID: id) {
            let nft <- FlowEVMBridgeNFTEscrow.unlockNFT(type: type, id: cadenceID)

            // If the NFT is bridge-defined, update the URI from the source ERC721 contract
            if self.account.address == FlowEVMBridgeUtils.getContractAddress(fromType: type) {
                nftContract!.updateTokenURI(evmID: id, newURI: uri)
            }

            return <-nft
        }

        /* Mint bridge-defined NFT */
        //
        // Ensure the NFT is bridge-defined
        assert(self.account.address == contractAddress, message: "Unexpected error bridging NFT from EVM")

        // We expect the NFT to be minted in Cadence as it is bridge-defined
        let nft <- nftContract!.mintNFT(id: id, tokenURI: uri)
        return <-nft
    }

    /**************************
        FT Handling
    ***************************/

    /// Public entrypoint to bridge FTs from Cadence to EVM as ERC20 tokens.
    ///
    /// @param vault: The fungible token Vault to be bridged
    /// @param to: The fungible token recipient in EVM
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun bridgeTokensToEVM(
        vault: @{FungibleToken.Vault},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !vault.isInstance(Type<@{NonFungibleToken.NFT}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(vault.getType()) == false: "FungibleToken must first be onboarded"
            FlowEVMBridgeConfig.isTypePaused(vault.getType()) == false: "Bridging is currently paused for this token"
        }
        /* Handle $FLOW requests via EVM interface & return */
        //
        let vaultType = vault.getType()

        // Gather the vault balance before acting on the resource
        let vaultBalance = vault.balance
        // Initialize fee amount to 0.0 and assign as appropriate for how the token is handled
        var feeAmount = 0.0

        /* TokenHandler coverage */
        //
        // Some tokens pre-dating bridge require special case handling - borrow handler and passthrough to fulfill
        if FlowEVMBridgeConfig.typeHasTokenHandler(vaultType) {
            let handler = FlowEVMBridgeConfig.borrowTokenHandler(vaultType)
                ?? panic("Could not retrieve handler for the given type")
            handler.fulfillTokensToEVM(tokens: <-vault, to: to)

            // Here we assume burning Vault in Cadence which doesn't require storage consumption
            feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: 0)
            FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: feeAmount)
            return
        }

        /* Escrow or burn tokens depending on native environment */
        //
        // In most all other cases, if Cadence-native then tokens must be escrowed
        if FlowEVMBridgeUtils.isCadenceNative(type: vaultType) {
            // Lock the FT balance & calculate the extra used by the FT if any
            let storageUsed = FlowEVMBridgeTokenEscrow.lockTokens(<-vault)
            // Calculate the bridge fee on current rates
            feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: storageUsed)
        } else {
            // Since not Cadence-native, bridge defines the token - burn the vault and calculate the fee
            Burner.burn(<-vault)
            feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: 0)
        }

        /* Provision fees */
        //
        // Withdraw fee amount from feeProvider and deposit
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: feeAmount)

        /* Gather identifying information */
        //
        // Does the bridge control the EVM contract associated with this type?
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: vaultType)
            ?? panic("No EVMAddress found for vault type")
        // Convert the vault balance to a UInt256
        let bridgeAmount = FlowEVMBridgeUtils.convertCadenceAmountToERC20Amount(
                vaultBalance,
                erc20Address: associatedAddress
            )
        assert(bridgeAmount > UInt256(0), message: "Amount to bridge must be greater than 0")

        // Determine if the EVM contract is bridge-owned - affects how tokens are transmitted to recipient
        let isFactoryDeployed = FlowEVMBridgeUtils.isEVMContractBridgeOwned(evmContractAddress: associatedAddress)

        /* Transmit tokens to recipient */
        //
        // Mint or transfer based on the bridge's EVM contract authority, making needed state assertions to confirm
        if isFactoryDeployed {
            FlowEVMBridgeUtils.mustMintERC20(to: to, amount: bridgeAmount, erc20Address: associatedAddress)
        } else {
            FlowEVMBridgeUtils.mustTransferERC20(to: to, amount: bridgeAmount, erc20Address: associatedAddress)
        }
    }

    /// Entrypoint to bridge ERC20 tokens from EVM to Cadence as FungibleToken Vaults
    ///
    /// @param owner: The EVM address of the FT owner. Current ownership and successful transfer (via
    ///     `protectedTransferCall`) is validated before the bridge request is executed.
    /// @param calldata: Caller-provided approve() call, enabling contract COA to operate on FT in EVM contract
    /// @param amount: The amount of tokens to be bridged
    /// @param evmContractAddress: Address of the EVM address defining the FT being bridged - also call target
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    /// @param protectedTransferCall: A function that executes the transfer of the FT from the named owner to the
    ///     bridge's COA. This function is expected to return a Result indicating the status of the transfer call.
    ///
    /// @returns The bridged fungible token Vault
    ///
    access(account)
    fun bridgeTokensFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        amount: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (): EVM.Result
    ): @{FungibleToken.Vault} {
        pre {
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !type.isSubtype(of: Type<@{NonFungibleToken.Collection}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(type) == false: "FungibleToken must first be onboarded"
            FlowEVMBridgeConfig.isTypePaused(type) == false: "Bridging is currently paused for this token"
        }
        /* Provision fees */
        //
        // Withdraw from feeProvider and deposit to self
        let feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: 0)
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: feeAmount)

        /* TokenHandler case coverage */
        //
        // Some tokens pre-dating bridge require special case handling. If such a case, fulfill via the related handler
        if FlowEVMBridgeConfig.typeHasTokenHandler(type) {
            //  - borrow handler and passthrough to fulfill
            let handler = FlowEVMBridgeConfig.borrowTokenHandler(type)
                ?? panic("Could not retrieve handler for the given type")
            return <-handler.fulfillTokensFromEVM(
                owner: owner,
                type: type,
                amount: amount,
                protectedTransferCall: protectedTransferCall
            )
        }

        /* Gather identifying information */
        //
        // Get the EVMAddress of the ERC20 contract associated with the type
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
            ?? panic("No EVMAddress found for token type")
        // Find the Cadence defining address and contract name
        let definingAddress = FlowEVMBridgeUtils.getContractAddress(fromType: type)!
        let definingContractName = FlowEVMBridgeUtils.getContractName(fromType: type)!
        // Convert the amount to a ufix64 so the amount can be settled on the Cadence side
        let ufixAmount = FlowEVMBridgeUtils.convertERC20AmountToCadenceAmount(amount, erc20Address: associatedAddress)
        assert(ufixAmount > 0.0, message: "Amount to bridge must be greater than 0")

        /* Execute the transfer call and make needed state assertions */
        //
        FlowEVMBridgeUtils.mustEscrowERC20(
            owner: owner,
            amount: amount,
            erc20Address: associatedAddress,
            protectedTransferCall: protectedTransferCall
        )

        /* Bridge-defined tokens are minted in Cadence */
        //
        // If the Cadence Vault is bridge-defined, mint the tokens
        if definingAddress == self.account.address {
            let minter = getAccount(definingAddress).contracts.borrow<&{IEVMBridgeTokenMinter}>(name: definingContractName)!
            return <- minter.mintTokens(amount: ufixAmount)
        }

        /* Cadence-native tokens are withdrawn from escrow */
        //
        // Confirm the EVM defining contract is bridge-owned before burning tokens
        assert(
            FlowEVMBridgeUtils.isEVMContractBridgeOwned(evmContractAddress: associatedAddress),
            message: "Unexpected error bridging FT from EVM"
        )
        // Burn the EVM tokens that have now been transferred to the bridge in EVM
        let burnResult: EVM.Result = FlowEVMBridgeUtils.call(
            signature: "burn(uint256)",
            targetEVMAddress: associatedAddress,
            args: [amount],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0
        )
        assert(burnResult.status == EVM.Status.successful, message: "Burn of EVM tokens failed")

        // Unlock from escrow and return
        return <-FlowEVMBridgeTokenEscrow.unlockTokens(type: type, amount: ufixAmount)
    }

    /**************************
        Public Getters
    **************************/

    /// Returns the EVM address associated with the provided type
    ///
    access(all)
    view fun getAssociatedEVMAddress(with type: Type): EVM.EVMAddress? {
        return FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
    }

    /// Retrieves the bridge contract's COA EVMAddress
    ///
    /// @returns The EVMAddress of the bridge contract's COA orchestrating actions in FlowEVM
    ///
    access(all)
    view fun getBridgeCOAEVMAddress(): EVM.EVMAddress {
        return FlowEVMBridgeUtils.borrowCOA().address()
    }

    /// Returns whether an asset needs to be onboarded to the bridge
    ///
    /// @param type: The Cadence Type of the asset
    ///
    /// @returns Whether the asset needs to be onboarded
    ///
    access(all)
    view fun typeRequiresOnboarding(_ type: Type): Bool? {
        if !FlowEVMBridgeUtils.isValidCadenceAsset(type: type) {
            return nil
        }
        return FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) == nil &&
            !FlowEVMBridgeConfig.typeHasTokenHandler(type)
    }

    /// Returns whether an EVM-native asset needs to be onboarded to the bridge
    ///
    /// @param address: The EVMAddress of the asset
    ///
    /// @returns Whether the asset needs to be onboarded, nil if the defined asset is not supported by this bridge
    ///
    access(all)
    fun evmAddressRequiresOnboarding(_ address: EVM.EVMAddress): Bool? {
        // See if the bridge already has a known type associated with the given address
        if FlowEVMBridgeConfig.getTypeAssociated(with: address) != nil {
            return false
        }
        // Dealing with EVM-native asset, check if it's NFT or FT exclusively
        if FlowEVMBridgeUtils.isValidEVMAsset(evmContractAddress: address) {
            return true
        }
        // Not onboarded and not a valid asset, so return nil
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
    fun deployEVMContract(forAssetType: Type): FlowEVMBridgeUtils.EVMOnboardingValues {
        pre {
            FlowEVMBridgeUtils.isValidCadenceAsset(type: forAssetType):
                "Asset type is not supported by the bridge"
        }
        let isNFT = forAssetType.isSubtype(of: Type<@{NonFungibleToken.NFT}>())

        let onboardingValues = FlowEVMBridgeUtils.getCadenceOnboardingValues(forAssetType: forAssetType)

        let deployedContractAddress = FlowEVMBridgeUtils.mustDeployEVMContract(
                name: onboardingValues.name,
                symbol: onboardingValues.symbol,
                cadenceAddress: onboardingValues.contractAddress,
                flowIdentifier: onboardingValues.identifier,
                contractURI: onboardingValues.contractURI,
                isERC721: isNFT
            )

        // Associate the deployed contract with the given type & return the deployed address
        FlowEVMBridgeConfig.associateType(forAssetType, with: deployedContractAddress)
        return FlowEVMBridgeUtils.EVMOnboardingValues(
            evmContractAddress: deployedContractAddress,
            name: onboardingValues.name,
            symbol: onboardingValues.symbol,
            decimals: isNFT ? nil : FlowEVMBridgeConfig.defaultDecimals,
            contractURI: onboardingValues.contractURI,
            cadenceContractName: FlowEVMBridgeUtils.getContractName(fromType: forAssetType)!,
            isERC721: isNFT
        )
    }

    /// Helper for deploying templated defining contract supporting EVM-native asset bridging to Cadence
    /// Deploys either NFT or FT contract depending on the provided type
    ///
    /// @param evmContractAddress: The EVMAddress currently defining the asset to be bridged
    ///
    access(self)
    fun deployDefiningContract(evmContractAddress: EVM.EVMAddress) {
        // Gather identifying information about the EVM contract
        let evmOnboardingValues = FlowEVMBridgeUtils.getEVMOnboardingValues(evmContractAddress: evmContractAddress)

        // Get Cadence code from template & deploy to the bridge account
        let cadenceCode: [UInt8] = FlowEVMBridgeTemplates.getBridgedAssetContractCode(
                evmOnboardingValues.cadenceContractName,
                isERC721: evmOnboardingValues.isERC721
            ) ?? panic("Problem retrieving code for Cadence-defining contract")
        if evmOnboardingValues.isERC721 {
            self.account.contracts.add(
                name: evmOnboardingValues.cadenceContractName,
                code: cadenceCode,
                evmOnboardingValues.name,
                evmOnboardingValues.symbol,
                evmContractAddress,
                evmOnboardingValues.contractURI
            )
        } else {
            self.account.contracts.add(
                name: evmOnboardingValues.cadenceContractName,
                code: cadenceCode,
                evmOnboardingValues.name,
                evmOnboardingValues.symbol,
                evmOnboardingValues.decimals!,
                evmContractAddress, evmOnboardingValues.contractURI
            )
        }

        emit BridgeDefiningContractDeployed(
            contractName: evmOnboardingValues.cadenceContractName,
            assetName: evmOnboardingValues.name,
            symbol: evmOnboardingValues.symbol,
            isERC721: evmOnboardingValues.isERC721,
            evmContractAddress: evmContractAddress.toString()
        )
    }
}
