import "FungibleToken"
import "FungibleTokenMetadataViews"
import "MetadataViews"
import "Burner"

import "FlowEVMBridgeHandlerInterfaces"

access(all) contract FiatToken: FungibleToken {

    // ------- FiatToken Events -------

    // FiatToken.Vault events
    access(all) event NewVault(resourceId: UInt64)
    access(all) event DestroyVault(resourceId: UInt64)

    // Minting events
    access(all) event MinterCreated(resourceId: UInt64)
    access(all) event Mint(minter: UInt64, amount: UFix64)
    access(all) event Burn(minter: UInt64, amount: UFix64)

    // ------- FiatToken Paths -------

    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultBalancePubPath: PublicPath
    access(all) let VaultReceiverPubPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    // ------- FiatToken States / Variables -------

    access(all) let name: String
    access(all) var version: String

    // The token total supply
    access(all) var totalSupply: UFix64

    // Blocked resources dictionary {resourceId: Block Height}
    access(contract) let blocklist: {UInt64: UInt64}

    // -------- ViewResolver Functions for MetadataViews --------

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
                        url: ""
                    ),
                    mediaType: ""
                )
                let medias = MetadataViews.Medias([media])
                return FungibleTokenMetadataViews.FTDisplay(
                    name: "Bridged Circle USDC",
                    symbol: "USDC",
                    description: "This is the Flow Bridged version of USDC in Cadence",
                    externalURL: MetadataViews.ExternalURL("https://www.circle.com/en/usdc"),
                    logos: medias,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/circle")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.VaultStoragePath,
                    receiverPath: self.VaultReceiverPubPath,
                    metadataPath: self.VaultBalancePubPath,
                    receiverLinkedType: Type<&FiatToken.Vault>(),
                    metadataLinkedType: Type<&FiatToken.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-FiatToken.createEmptyVault(vaultType: Type<@FiatToken.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: FiatToken.totalSupply
                )
        }
        return nil
    }

    // ------- Old FiatToken Interfaces, kept for backwards compatibility, but all functionality has been removed
    access(all) resource interface ResourceId {}
    access(all) resource interface AdminCapReceiver {}
    access(all) resource interface OwnerCapReceiver {}
    access(all) resource interface MasterMinterCapReceiver {}
    access(all) resource interface BlocklisterCapReceiver {}
    access(all) resource interface PauseCapReceiver {}

    // ------- Old FiatToken Resources, kept for backwards compatibility, but all functionality has been removed
    access(all) resource AdminExecutor {}
    access(all) resource Admin: ResourceId, AdminCapReceiver {}
    access(all) resource OwnerExecutor {}
    access(all) resource Owner: ResourceId, OwnerCapReceiver {}
    access(all) resource MasterMinterExecutor {}
    access(all) resource MasterMinter: ResourceId, MasterMinterCapReceiver {}
    access(all) resource MinterController: ResourceId {}
    access(all) resource Minter: ResourceId {}
    access(all) resource BlocklistExecutor {}
    access(all) resource Blocklister: ResourceId, BlocklisterCapReceiver {}
    access(all) resource PauseExecutor {}
    access(all) resource Pauser: ResourceId, PauseCapReceiver {}

    // ------- FiatToken Resources -------

    access(all) resource Vault:
        ResourceId,
        FungibleToken.Vault {

        access(all) var balance: UFix64

        /// Called when a fungible token is burned via the `Burner.burn()` method
        /// The total supply will only reflect the supply in the Cadence version
        /// of the FiatToken smart contract
        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                FiatToken.totalSupply = FiatToken.totalSupply - self.balance
            }
            self.balance = 0.0
        }

        access(all) view fun getViews(): [Type] {
            return FiatToken.getContractViews(resourceType: nil)
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return FiatToken.resolveContractView(resourceType: nil, viewType: view)
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

        access(all) fun createEmptyVault(): @FiatToken.Vault {
            return <-create Vault(balance: 0.0)
        }

        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                FiatToken.blocklist[self.uuid] == nil: "Vault Blocklisted"
            }
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            pre {
                FiatToken.blocklist[from.uuid] == nil: "Receiving Vault Blocklisted"
                FiatToken.blocklist[self.uuid] == nil: "Vault Blocklisted"
            }
            let vault <- from as! @FiatToken.Vault
            self.balance = self.balance + vault.balance
            vault.balance = 0.0
            destroy vault
        }

        access(all) view fun UUID(): UInt64 {
            return self.uuid
        }

        init(balance: UFix64) {
            self.balance = balance
        }
    }

    access(all) resource MinterResource : FlowEVMBridgeHandlerInterfaces.TokenMinter {

        access(all) view fun getMintedType(): Type {
            return Type<@FiatToken.Vault>()
        }

        access(all) fun mint(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                FiatToken.blocklist[self.uuid] == nil: "Minter Blocklisted"
            }
            let newTotalSupply = FiatToken.totalSupply + amount
            FiatToken.totalSupply = newTotalSupply

            emit Mint(minter: self.uuid, amount: amount)
            return <-create Vault(balance: amount)
        }

        access(all) fun burn(vault: @{FungibleToken.Vault}) {
            let toBurn <- vault as! @FiatToken.Vault
            let amount = toBurn.balance

            assert(FiatToken.totalSupply >= amount, message: "burning more than total supply")

            // This function updates FiatToken.totalSupply and sets the Vault's value to 0.0
            Burner.burn(<-toBurn)
            emit Burn(minter: self.uuid, amount: amount)
        }
    }

    // ------- FiatToken functions -------

    access(all) fun createEmptyVault(vaultType: Type): @Vault {
        let r <-create Vault(balance: 0.0)
        emit NewVault(resourceId: r.uuid)
        return <-r
    }

    // ------- FiatToken Initializer -------
    init(
        VaultStoragePath: StoragePath,
        VaultBalancePubPath: PublicPath,
        VaultReceiverPubPath: PublicPath,
        MinterStoragePath: StoragePath,
        tokenName: String,
        version: String,
        initTotalSupply: UFix64,
    ) {
        // Set the State
        self.name = tokenName
        self.version = version
        self.totalSupply = initTotalSupply
        self.blocklist = {}

        self.VaultStoragePath = VaultStoragePath
        self.VaultBalancePubPath = VaultBalancePubPath
        self.VaultReceiverPubPath = VaultReceiverPubPath

        self.MinterStoragePath = MinterStoragePath

        // Create a Vault with the initial totalSupply
        let vault <- create Vault(balance: self.totalSupply)
        self.account.storage.save(<-vault, to: self.VaultStoragePath)

        // Create a Vault with the initial totalSupply
        let minter <- create MinterResource()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)

        // Create public capabilities to the vault
        let tokenCap = self.account.capabilities.storage.issue<&FiatToken.Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(tokenCap, at: self.VaultReceiverPubPath)
        let receiverCap = self.account.capabilities.storage.issue<&FiatToken.Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(receiverCap, at: self.VaultBalancePubPath)
    }
}
