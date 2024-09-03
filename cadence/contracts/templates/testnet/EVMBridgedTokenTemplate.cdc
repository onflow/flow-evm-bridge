import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import FungibleTokenMetadataViews from 0x9a0766d93b6608b7
import ViewResolver from 0x631e88ae7f1d7c20
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

import EVM from 0x8c5303eaa26202d6

import ICrossVM from 0xdfc20aee650fcbdf
import ICrossVMAsset from 0xdfc20aee650fcbdf
import IEVMBridgeTokenMinter from 0xdfc20aee650fcbdf
import FlowEVMBridgeTokenEscrow from 0xdfc20aee650fcbdf
import FlowEVMBridgeConfig from 0xdfc20aee650fcbdf
import FlowEVMBridgeUtils from 0xdfc20aee650fcbdf
import FlowEVMBridge from 0xdfc20aee650fcbdf
import CrossVMToken from 0xdfc20aee650fcbdf
import FlowEVMBridgeResolver from 0xdfc20aee650fcbdf

/// This contract is a template used by FlowEVMBridge to define EVM-native fungible tokens bridged from Flow EVM to 
/// Cadence. Upon deployment of this contract, the contract name is derived as a function of the asset type (here an 
/// ERC20) and the contract's EVM address. The derived contract name is then joined with this contract's code,
/// prepared as chunks in FlowEVMBridgeTemplates before being deployed to the Flow EVM Bridge account.
///
/// On bridging, the ERC20 is transferred to the bridge's CadenceOwnedAccount EVM address and tokens are minted from
/// this contract to the bridging caller. On return to Flow EVM, the reverse process is followed - the token is burned
/// in this contract and the ERC20 is transferred to the defined recipient. In this way, the Cadence Vault acts as a
/// representation of both the EVM tokens and thus ownership rights to it upon bridging back to Flow EVM.
///
/// To bridge between VMs, a caller can either use the interface exposed on CadenceOwnedAccount or use FlowEVMBridge
/// public contract methods.
///
access(all) contract {{CONTRACT_NAME}} : ICrossVM, ICrossVMAsset, IEVMBridgeTokenMinter, FungibleToken {

    /// Pointer to the Factory deployed Solidity contract address defining the bridged asset
    access(all) let evmTokenContractAddress: EVM.EVMAddress
    /// Name of the fungible token defined in the corresponding ERC20 contract
    access(all) let name: String
    /// Symbol of the fungible token defined in the corresponding ERC20 contract
    access(all) let symbol: String
    /// Decimal place value defined in the source ERC20 contract
    access(all) let decimals: UInt8
    /// URI of the contract, if available as a var in case the bridge enables cross-VM Metadata syncing in the future
    access(all) var contractURI: String?
    /// Total supply of this Cadence token in circulation
    /// NOTE: This does not reflect the total supply of the source ERC20 in circulation within EVM
    access(all) var totalSupply: UFix64
    /// Retain a Vault to reference when resolving Vault Metadata
    access(self) let vault: @Vault

    /// The Vault resource representing the bridged ERC20 token
    ///
    access(all) resource Vault : ICrossVMAsset.AssetInfo, CrossVMToken.EVMTokenInfo, FungibleToken.Vault {
        /// Balance of the tokens in a given Vault
        access(all) var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        /* --- CrossVMToken.EVMFTVault conformance --- */
        //
        /// Gets the ERC20 name value
        access(all) view fun getName(): String {
            return {{CONTRACT_NAME}}.name
        }
        /// Gets the ERC20 symbol value
        access(all) view fun getSymbol(): String {
            return {{CONTRACT_NAME}}.symbol
        }
        /// Gets the ERC20 decimals value
        access(all) view fun getDecimals(): UInt8 {
            return {{CONTRACT_NAME}}.decimals
        }
        /// Returns the EVM contract address of the fungible token
        access(all) view fun getEVMContractAddress(): EVM.EVMAddress {
            return {{CONTRACT_NAME}}.getEVMContractAddress()
        }

        access(all) view fun getViews(): [Type] {
            return {{CONTRACT_NAME}}.getContractViews(resourceType: nil)
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return {{CONTRACT_NAME}}.resolveContractView(resourceType: nil, viewType: view)
        }

        /// getSupportedVaultTypes optionally returns a list of vault types that this receiver accepts
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return { self.getType(): true }
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
        }

        /// Asks if the amount can be withdrawn from this vault
        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        /// deposit
        ///
        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        ///
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @Vault
            self.balance = self.balance + vault.balance
            vault.balance = 0.0
            destroy vault
        }

        /// createEmptyVault
        ///
        /// Function that creates a new Vault with a balance of zero
        /// and returns it to the calling context. A user must call this function
        /// and store the returned Vault in their storage in order to allow their
        /// account to be able to receive deposits of this token type.
        ///
        access(all) fun createEmptyVault(): @Vault {
            return <-create Vault(balance: 0.0)
        }

        /// withdraw
        ///
        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        ///
        /// It creates a new temporary Vault that is used to hold
        /// the tokens that are being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @Vault {
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        /// Called when a fungible token is burned via the `Burner.burn()` method
        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                {{CONTRACT_NAME}}.totalSupply = {{CONTRACT_NAME}}.totalSupply - self.balance
            }
            self.balance = 0.0
        }
    }

    /// createEmptyVault
    ///
    /// Function that creates a new Vault with a balance of zero and returns it to the calling context. A user must call
    /// this function and store the returned Vault in their storage in order to allow their account to be able to
    /// receive deposits of this token type.
    ///
    access(all) fun createEmptyVault(vaultType: Type): @{{CONTRACT_NAME}}.Vault {
        return <- create Vault(balance: 0.0)
    }

    /**********************
            Getters
    ***********************/

    /// Returns the name of the asset
    ///
    access(all) view fun getName(): String {
        return self.name
    }

    /// Returns the symbol of the asset
    ///
    access(all) view fun getSymbol(): String {
        return self.symbol
    }

    /// Returns the EVM contract address of the fungible token this contract represents
    ///
    access(all) view fun getEVMContractAddress(): EVM.EVMAddress {
        return self.evmTokenContractAddress
    }

    /// Function that returns all the Metadata Views implemented by this fungible token contract.
    ///
    /// @return An array of Types defining the implemented views. This value will be used by developers to know which
    ///         parameter to pass to the resolveContractView() method.
    ///
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>(),
            Type<FungibleTokenMetadataViews.TotalSupply>(),
            Type<MetadataViews.EVMBridgedMetadata>()
        ]
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    ///
    /// @return A structure representing the requested view.
    ///
    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let contractRef = self.borrowThisContract()
                return FlowEVMBridgeResolver.resolveBridgedView(bridgedContract: contractRef, view: Type<FungibleTokenMetadataViews.FTDisplay>())
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: /storage/{{CONTRACT_NAME}}Vault,
                    receiverPath: /public/{{CONTRACT_NAME}}Receiver,
                    metadataPath: /public/{{CONTRACT_NAME}}Vault,
                    receiverLinkedType: Type<&{{CONTRACT_NAME}}.Vault>(),
                    metadataLinkedType: Type<&{{CONTRACT_NAME}}.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-self.createEmptyVault(vaultType: Type<@{{CONTRACT_NAME}}.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: self.totalSupply
                )
            case Type<MetadataViews.EVMBridgedMetadata>():
                return MetadataViews.EVMBridgedMetadata(
                    name: self.name,
                    symbol: self.symbol,
                    uri: self.contractURI != nil ? MetadataViews.URI(baseURI: nil, value: self.contractURI!) : MetadataViews.URI(baseURI: nil, value: "")
                )
        }
        return nil
    }

    /**********************
        Internal Methods
    ***********************/

    /// Allows the bridge to mint tokens from bridge-defined fungible token contracts
    ///
    access(account) fun mintTokens(amount: UFix64): @{FungibleToken.Vault} {
        self.totalSupply = self.totalSupply + amount
        return <- create Vault(balance: amount)
    }

    /// Returns a reference to this contract as an ICrossVMAsset contract
    ///
    access(self)
    fun borrowThisContract(): &{ICrossVMAsset} {
        let contractAddress = self.account.address
        return getAccount(contractAddress).contracts.borrow<&{ICrossVMAsset}>(name: "{{CONTRACT_NAME}}")!
    }

    init(name: String, symbol: String, decimals: UInt8, evmContractAddress: EVM.EVMAddress, contractURI: String?) {
        self.evmTokenContractAddress = evmContractAddress
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
        self.contractURI = contractURI
        self.totalSupply = 0.0
        self.vault <- create Vault(balance: 0.0)

        FlowEVMBridgeConfig.associateType(Type<@{{CONTRACT_NAME}}.Vault>(), with: self.evmTokenContractAddress)
        FlowEVMBridgeTokenEscrow.initializeEscrow(
            with: <-create Vault(balance: 0.0),
            name: name,
            symbol: symbol,
            decimals: decimals,
            evmTokenAddress: self.evmTokenContractAddress
        )
    }
}
