import "FungibleToken"
import "FungibleTokenMetadataViews"
import "MetadataViews"
import "Burner"

import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeConfig"

/// USDCFlow
///
/// Defines the Cadence version of bridged Flow USDC. 
/// Before the Sept 4th, 2024 Crescendo migration, users can send
/// `FiatToken` vaults to the `USDCFlow.wrapFiatToken()` function
/// and receive `USDCFlow` vaults back with the exact same balance.

/// After the Crescendo migration, the `USDCFlow` smart contract
/// will integrate directly with the Flow VM bridge to become
/// the bridged version of Flow EVM USDC. These tokens will be backed
/// by real USDC via Flow EVM.

/// This is not the official Circle USDC, only a bridged version
/// that is still backed by official USDC on the other side of the bridge

access(all) contract USDCFlow: FungibleToken {

    /// Total supply of USDCFlows in existence
    access(all) var totalSupply: UFix64

    /// Storage and Public Paths
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let ReceiverPublicPath: PublicPath

    /// The event that is emitted when new tokens are minted
    access(all) event Minted(amount: UFix64, mintedUUID: UInt64)
    access(all) event Burned(amount: UFix64, burntUUID: UInt64)

    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>(),
            Type<FungibleTokenMetadataViews.TotalSupply>()
        ]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                        url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                    ),
                    mediaType: "image/svg+xml"
                )
                let medias = MetadataViews.Medias([media])
                return FungibleTokenMetadataViews.FTDisplay(
                    name: "USDC (Flow)",
                    symbol: "USDCf",
                    description: "This fungible token representation of USDC is bridged from Flow EVM.",
                    externalURL: MetadataViews.ExternalURL("https://www.circle.com/en/usdc"),
                    logos: medias,
                    socials: {
                        "x": MetadataViews.ExternalURL("https://x.com/circle")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: USDCFlow.VaultStoragePath,
                    receiverPath: USDCFlow.ReceiverPublicPath,
                    metadataPath: USDCFlow.VaultPublicPath,
                    receiverLinkedType: Type<&USDCFlow.Vault>(),
                    metadataLinkedType: Type<&USDCFlow.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-USDCFlow.createEmptyVault(vaultType: Type<@USDCFlow.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: USDCFlow.totalSupply
                )
        }
        return nil
    }

    access(all) resource Vault: FungibleToken.Vault {

        /// The total balance of this vault
        access(all) var balance: UFix64

        /// Initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        /// Called when a fungible token is burned via the `Burner.burn()` method
        /// The total supply will only reflect the supply in the Cadence version
        /// of the USDCFlow smart contract
        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                assert(USDCFlow.totalSupply >= self.balance, message: "Cannot burn more than the total supply")
                emit Burned(amount: self.balance, burntUUID: self.uuid)
                USDCFlow.totalSupply = USDCFlow.totalSupply - self.balance
            }
            self.balance = 0.0
        }

        /// getSupportedVaultTypes optionally returns a list of vault types that this receiver accepts
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[self.getType()] = true
            return supportedTypes
        }

        /// Returns whether the specified type can be deposited
        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
        }

        /// Asks if the amount can be withdrawn from this vault
        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        access(all) fun createEmptyVault(): @USDCFlow.Vault {
            return <-create Vault(balance: 0.0)
        }

        /// withdraw
        /// @param amount: The amount of tokens to be withdrawn from the vault
        /// @return The Vault resource containing the withdrawn funds
        ///
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        /// deposit
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @USDCFlow.Vault
            self.balance = self.balance + vault.balance
            destroy vault
        }

        /// Gets an array of all the Metadata Views implemented by USDCFlow
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        access(all) view fun getViews(): [Type] {
            return USDCFlow.getContractViews(resourceType: nil)
        }

        /// Resolves Metadata Views out of the USDCFlow
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return USDCFlow.resolveContractView(resourceType: nil, viewType: view)
        }
    }

    access(all) resource Minter: FlowEVMBridgeHandlerInterfaces.TokenMinter {

        /// Required function for the bridge to be able to work with the Minter
        access(all) view fun getMintedType(): Type {
            return Type<@USDCFlow.Vault>()
        }

        /// Function for the bridge to mint tokens that are bridged from Flow EVM
        access(FlowEVMBridgeHandlerInterfaces.Mint) fun mint(amount: UFix64): @{FungibleToken.Vault} {
            let newTotalSupply = USDCFlow.totalSupply + amount
            USDCFlow.totalSupply = newTotalSupply

            let vault <-create Vault(balance: amount)

            emit Minted(amount: amount, mintedUUID: vault.uuid)
            return <-vault
        }

        /// Function for the bridge to burn tokens that are bridged back to Flow EVM
        access(all) fun burn(vault: @{FungibleToken.Vault}) {
            let toBurn <- vault as! @USDCFlow.Vault
            let amount = toBurn.balance

            // This function updates USDCFlow.totalSupply
            Burner.burn(<-toBurn)
        }
    }

    /// Sends the USDCFlow Minter to the Flow/EVM bridge
    /// without giving any account access to the minter
    /// before it is safely in the decentralized bridge
    access(all) fun sendMinterToBridge(_ bridgeAddress: Address) {
        let minter <- create Minter()
        // borrow a reference to the bridge's configuration admin resource from public Capability
        let bridgeAdmin = getAccount(bridgeAddress).capabilities.borrow<&FlowEVMBridgeConfig.Admin>(
                FlowEVMBridgeConfig.adminPublicPath
            ) ?? panic("FlowEVMBridgeConfig.Admin could not be referenced from ".concat(bridgeAddress.toString()))
            
        // sets the USDCFlow as the minter resource for all USDCFlow bridge requests
        // prior to transferring the Minter, a TokenHandler will be set for USDCFlow during the bridge's initial
        // configuration, setting the stage for this minter to be sent.
        bridgeAdmin.setTokenHandlerMinter(targetType: Type<@USDCFlow.Vault>(), minter: <-minter)
    }

    /// createEmptyVault
    ///
    /// @return The new Vault resource with a balance of zero
    ///
    access(all) fun createEmptyVault(vaultType: Type): @Vault {
        let r <-create Vault(balance: 0.0)
        return <-r
    }

    init() {
        self.totalSupply = 0.0
        self.VaultStoragePath = /storage/usdcFlowVault
        self.VaultPublicPath = /public/usdcFlowMetadata
        self.ReceiverPublicPath = /public/usdcFlowReceiver

        let minter <- create Minter()
        self.account.storage.save(<-minter, to: /storage/usdcFlowMinter)

        // Create the Vault with the total supply of tokens and save it in storage.
        let vault <- create Vault(balance: self.totalSupply)
        self.account.storage.save(<-vault, to: self.VaultStoragePath)

        let tokenCap = self.account.capabilities.storage.issue<&USDCFlow.Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(tokenCap, at: self.ReceiverPublicPath)
        self.account.capabilities.publish(tokenCap, at: self.VaultPublicPath)
    }
}