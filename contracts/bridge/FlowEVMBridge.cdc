import "FlowToken"

import "EVM"

import "FlowEVMBridgeUtils"
import "IEVMBridgeNFTLocker"
import "FlowEVMBridgeTemplates"

access(all) contract FlowEVMBridge {

    /// Amount of $FLOW paid to bridge
    access(all) var fee: UFix64
    /// The COA which orchestrates bridge operations in EVM
    access(self) let coa: @EVM.BridgedAccount

    /// Denotes a contract was deployed to the bridge account, could be either FlowEVMBridgeLocker or FlowEVMBridgedAsset
    access(all) event BridgeContractDeployed(type: Type, name: String, evmContractAddress: EVM.EVMAddress)

    /* --- Public NFT Handling --- */

    /// Public entrypoint to bridge NFTs from Flow to EVM - cross-account bridging supported
    ///
    /// @param token: The NFT to be bridged
    /// @param to: The NFT recipient in FlowEVM
    /// @param tollFee: The fee paid for bridging
    ///
    access(all) fun bridgeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault) {
        pre {
            tollFee.balance >= self.tollAmount: "Insufficient fee paid"
            asset.isInstance(of: Type<&{FungibleToken.Vault}>) == false: "Mixed asset types are not yet supported"
        }
        if FlowEVMBridgeUtils.isFlowNative(asset: &tokens as &AnyResource) {
            self.bridgeFlowNativeNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
        } else {
            self.bridgeEVMNativeNFTToEVM(token: <-token, to: to, tollFee: <-tollFee)
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
    access(all) fun bridgeNFTFromEVM(
        caller: auth(Callable) &BridgedAccount,
        calldata: [UInt8],
        id: UInt64,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @FlowToken.Vault
    ): @{NonFungibleToken.NFT} {
        pre {
            tollFee.balance >= self.tollAmount: "Insufficient fee paid"
            FlowEVMBridgeUtils.isEVMNFT(evmContractAddress: evmContractAddress): "Unsupported asset type"
            FlowEVMBridgeUtils.isOwnerOrApproved(ofNFT: id, owner: caller.address(), evmContractAddress: evmContractAddress):
                "Caller is not the owner of or approved for requested NFT"
        }
    }

    /* --- Public FT Handling --- */

    /// Public entrypoint to bridge NFTs from Flow to EVM - cross-account bridging supported
    ///
    /// @param vault: The FungibleToken Vault to be bridged
    /// @param to: The recipient of tokens in FlowEVM
    /// @param tollFee: The fee paid for bridging
    ///
    // access(all) fun bridgeTokensToEVM(vault: @{FungibleToken.Vault}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault) {
    //     pre {
    //         tollFee.balance >= self.tollAmount: "Insufficient fee paid"
    //         asset.isInstance(of: Type<&{NonFungibleToken.NFT}>) == false: "Mixed asset types are not yet supported"
    //     }
    //     // Handle based on whether Flow- or EVM-native & passthrough to internal method
    // }

    /// Public entrypoint to bridge fungible tokens from EVM to Flow
    ///
    /// @param caller: The caller executing the bridge - must be passed to check EVM state pre- & post-call in scope
    /// @param calldata: Caller-provided approve() call, enabling contract COA to operate on tokens in EVM contract
    /// @param amount: The amount of tokens to bridge
    /// @param evmContractAddress: Address of the EVM address defining the tokens being bridged, also call target
    /// @param tollFee: The fee paid for bridging
    ///
    // access(all) fun bridgeTokensFromEVM(
    //     caller: auth(Callable) &BridgedAccount,
    //     calldata: [UInt8],
    //     amount: UFix64,
    //     evmContractAddress: EVM.EVMAddress,
    //     tollFee: @FlowToken.Vault
    // ): @{FungibleToken.Vault} {
    //     pre {
    //         tollFee.balance >= self.tollAmount: "Insufficient fee paid"
    //         FlowEVMBridgeUtils.isEVMToken(evmContractAddress: evmContractAddress): "Unsupported asset type"
    //         FlowEVMBridgeUtils.hasSufficientBalance(amount: amount, owner: caller, evmContractAddress: evmContractAddress):
    //             "Caller does not have sufficient funds to bridge requested amount"
    //     }
    // }

    /* --- Public Getters --- */

    /// Returns the bridge contract's COA EVMAddress
    access(all) fun getBridgeCOAEVMAddress(): EVM.EVMAddress {
        return self.coa.address()
    }
    /// Retrieves the EVM address of the contract related to the bridge contract-defined asset
    /// Useful for bridging flow-native assets back from EVM
    access(all) fun getAssetEVMContractAddress(type: Type): EVM.EVMAddress? {

    }
    /// Retrieves the Flow address associated with the asset defined at the provided EVM address if it's defined
    /// in a bridge-deployed contract
    access(all) fun getAssetFlowContractAddress(evmAddress: EVM.EVMAddress): Address?

    /* --- Internal Helpers --- */

    // Flow-native NFTs - lock & unlock

    /// Handles bridging Flow-native NFTs to EVM - locks NFT in designated Flow locker contract & mints in EVM
    /// Within scope, locker contract is deployed if needed & passing on call to said contract
    access(self) fun bridgeFlowNativeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault) {
        let lockerContractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: token.getType())
        if self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName) == nil {
            self.deployLockerContract(asset: &token as &AnyResource)
        }
        let lockerContract = self.account.contracts.borrow<&IEVMBridgeNFTLocker>(name: lockerContractName)
            ?? panic("Problem configuring Locker contract for token type: ".concat(token.getType().identifier))
        lockerContract.bridgeToEVM(token: <-token, to: to, tollFee: <-tollFee)
    }
    /// Handles bridging Flow-native NFTs from EVM - unlocks NFT from designated Flow locker contract & burns in EVM
    /// Within scope, locker contract is deployed if needed & passing on call to said contract
    access(self) fun bridgeFlowNativeNFTFromEVM(
        caller: auth(Callable) &BridgedAccount,
        calldata: [UInt8],
        id: UInt256,
        evmContractAddress: EVM.EVMAddress
        tollFee: @FlowToken.Vault
    )

    // EVM-native NFTs - mint & burn

    /// Handles bridging EVM-native NFTs to EVM - burns NFT in defining Flow contract & transfers in EVM
    /// Within scope, defining contract is deployed if needed & passing on call to said contract
    // access(self) fun bridgeEVMNativeNFTToEVM(token: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault)
    /// Handles bridging EVM-native NFTs to EVM - mints NFT in defining Flow contract & transfers in EVM
    /// Within scope, defining contract is deployed if needed & passing on call to said contract
    // access(self) fun bridgeEVMNativeNFTFromEVM(
    //     caller: auth(Callable) &BridgedAccount,
    //     calldata: [UInt8],
    //     id: UInt256,
    //     evmContractAddress: EVM.EVMAddress
    //     tollFee: @FlowToken.Vault
    // )

    // Flow-native FTs - lock & unlock

    /// Handles bridging Flow-native assets to EVM - locks Vault in designated Flow locker contract & mints in EVM
    /// Within scope, locker contract is deployed if needed
    access(self) fun bridgeFlowNativeTokensToEVM(vault: @{FungibleToken.Vault}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault)
    /// Handles bridging Flow-native assets from EVM - unlocks Vault from designated Flow locker contract & burns in EVM
    /// Within scope, locker contract is deployed if needed
    access(self) fun bridgeFlowNativeTokensFromEVM(
        caller: auth(Callable) &BridgedAccount,
        calldata: [UInt8],
        amount: UFix64,
        evmContractAddress: EVM.EVMAddress,
        tollFee: @FlowToken.Vault
    )

    // EVM-native FTs - mint & burn

    /// Handles bridging EVM-native assets to EVM - burns Vault in defining Flow contract & transfers in EVM
    /// Within scope, defining contract is deployed if needed
    // access(self) fun bridgeEVMNativeTokensToEVM(vault: @{FungibleToken.Vault}, to: EVM.EVMAddress, tollFee: @FlowToken.Vault)
    /// Handles bridging EVM-native assets from EVM - mints Vault from defining Flow contract & transfers in EVM
    /// Within scope, defining contract is deployed if needed
    // access(self) fun bridgeEVMNativeTokensFromEVM(
    //     caller: auth(Callable) &BridgedAccount,
    //     calldata: [UInt8],
    //     amount: UFix64,
    //     evmContractAddress: EVM.EVMAddress,
    //     tollFee: @FlowToken.Vault
    // )
    
    /// Helper for deploying templated Locker contract supporting Flow-native asset bridging to EVM
    /// Deploys either NFT or FT locker depending on the asset type
    access(self) fun deployLockerContract(asset: &AnyResource) {

    }
    /// Helper for deploying templated defining contract supporting EVM-native asset bridging to Flow
    /// Deploys either NFT or FT contract depending on the provided type
    access(self) fun deployDefiningContract(type: Type)

    /// Enables other bridge contracts to orchestrate bridge operations from contract-owned COA
    access(account) fun borrowCOA(): &EVM.BridgedAccount {
        return &self.coa as &EVM.BridgedAccount
    }

    init() {
        self.fee = 0.0
        self.coa <- self.account.storage.load<@EVM.BridgedAccount>(from: /storage/flowEVMBridgeCOA)
    }
}
