import "FungibleToken"
import "NonFungibleToken"
import "FlowToken"

import "EVM"

import "ICrossVM"
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
    access(all) event BridgeLockerContractDeployed(type: Type, name: String, evmContractAddress: EVM.EVMAddress)
    /// Denotes a defining contract was deployed to the bridge account
    access(all) event BridgeDefiningContractDeployed(type: Type, name: String, evmContractAddress: EVM.EVMAddress)

    /**************************
        Public NFT Handling
    **************************/

    /// Onboards a given type of NFT to the bridge. Since we're onboarding by Cadence Type, the asset must be defined
    /// in a third-party contract. Attempting to onboard a bridge-defined asset will result in an error as onboarding
    /// is not required
    ///
    /// @param type: The Cadence Type of the NFT to be onboarded
    /// @param tollFee: Fee paid for onboarding
    ///
    access(all) fun onboardNFTByType(_ type: Type, tollFee: @FlowToken.Vault) {
        pre {
            self.typeRequiresOnboarding(type) == true: "Onboarding is not needed for this type"
        }
        FlowEVMBridgeUtils.depositTollFee(<-tollFee)
        if FlowEVMBridgeUtils.isFlowNative(type: type) {
            self.deployLockerContract(forType: type)
        } else {
            // TODO: EVM-native NFT path - deploy defining contract
            // self.deployLockerContract(forType: type)
        }
    }

    /// Public entrypoint to bridge NFTs from Flow to EVM - cross-account bridging supported (e.g. straight to EOA)
    ///
    /// @param token: The NFT to be bridged
    /// @param to: The NFT recipient in FlowEVM
    /// @param tollFee: The fee paid for bridging
    ///
    access(all) fun bridgeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault) {
        pre {
            tollFee.balance >= FlowEVMBridgeConfig.fee: "Insufficient fee paid"
            token.isInstance(Type<@{FungibleToken.Vault}>()) == false: "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(token.getType()) == false: "NFT must first be onboarded"
        }
        if FlowEVMBridgeUtils.isFlowNative(type: token.getType()) {
            self.bridgeFlowNativeNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
        } else {
            // TODO: EVM-native NFT path
            // self.bridgeEVMNativeNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
            destroy <- token
            destroy <- tollFee
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
    access(all) fun bridgeNFTFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @FlowToken.Vault
    ): @{NonFungibleToken.NFT} {
        pre {
            tollFee.balance >= FlowEVMBridgeConfig.fee: "Insufficient fee paid"
        }
        if FlowEVMBridgeUtils.isEVMNative(evmContractAddress: evmContractAddress) {
            // TODO: EVM-native NFT path
        } else {
            return <- self.bridgeFlowNativeNFTFromEVM(
                caller: caller,
                calldata: calldata,
                id: id,
                evmContractAddress: evmContractAddress,
                tollFee: <-tollFee
            )
        }
        panic("Could not route bridge request for the requested NFT")
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
    // TODO: Can be made `view` when BridgedAccount.address() is `view`
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

        // If the type is defined by the bridge, it's EVM-native and has already been onboarded
        if FlowEVMBridgeUtils.getContractAddress(fromType: type) == self.account.address {
            return false
        }

        // Otherwise, the type is Flow-native, so check if the locker contract is deployed
        if let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: type) {
            return self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName) == nil
        }

        return nil
    }

    /// Returns whether an EVM-native asset needs to be onboarded to the bridge
    // TODO
    access(all) fun evmAddressRequiresOnboarding(address: EVM.EVMAddress) {}

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

    /* --- FLOW-NATIVE NFTs | lock & unlock in Cadence / mint & burn in EVM --- */

    /// Handles bridging Flow-native NFTs to EVM - locks NFT in designated Flow locker contract & mints in EVM
    /// Within scope, locker contract is deployed if needed & passing on call to said contract
    ///
    access(self) fun bridgeFlowNativeNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        tollFee: @FlowToken.Vault
    ) {
        let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: token.getType()) ??
            panic("Could not derive locker contract name for token type: ".concat(token.getType().identifier))
        log(lockerContractName)
        if self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName) == nil {
            self.deployLockerContract(forType: token.getType())
        }

        let lockerContract: &IEVMBridgeNFTLocker = self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName)
            ?? panic("Problem locating Locker contract for token type: ".concat(token.getType().identifier))
        lockerContract.bridgeToEVM(token: <-token, to: to, tollFee: <-tollFee)
    }
    /// Handles bridging Flow-native NFTs from EVM - unlocks NFT from designated Flow locker contract & burns in EVM
    /// Within scope, locker contract is deployed if needed & passing on call to said contract
    ///
    access(self) fun bridgeFlowNativeNFTFromEVM(
        caller: &EVM.BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @FlowToken.Vault
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
        return <- lockerContract.bridgeFromEVM(
            caller: caller,
            calldata: calldata,
            id: id,
            evmContractAddress: evmContractAddress,
            tollFee: <-tollFee
        )
    }

    /* --- EVM-NATIVE NFTs | mint & burn in Cadence / lock & unlock in EVM --- */

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

        emit BridgeLockerContractDeployed(type: forType, name: name, evmContractAddress: evmContractAddress)
    }
    
    /// Helper for deploying templated defining contract supporting EVM-native asset bridging to Flow
    /// Deploys either NFT or FT contract depending on the provided type
    // TODO
    access(self) fun deployDefiningContract(type: Type) {}

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
}
