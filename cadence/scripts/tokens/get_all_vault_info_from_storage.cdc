import "FungibleToken"
import "FlowToken"
import "MetadataViews"
import "FungibleTokenMetadataViews"

access(all)
struct FTVaultInfo {
    access(all) let name: String
    access(all) let symbol: String
    access(all) var balance: UFix64
    access(all) let tokenContractAddress: Address
    access(all) let tokenContractName: String
    access(all) let storagePath: StoragePath
    access(all) let receiverPath: PublicPath

    init(
        name: String,
        symbol: String,
        balance: UFix64,
        tokenContractAddress: Address,
        tokenContractName: String,
        storagePath: StoragePath,
        receiverPath: PublicPath
    ) {
        self.name = name
        self.symbol = symbol
        self.balance = balance
        self.tokenContractAddress = tokenContractAddress
        self.tokenContractName = tokenContractName
        self.storagePath = storagePath
        self.receiverPath = receiverPath
    }

    access(all) fun updateBalance(delta: UFix64) {
        self.balance = self.balance + delta
    }
}

access(all)
fun getVaultInfo(
    vaultType: Type,
    balance: UFix64,
    display: FungibleTokenMetadataViews.FTDisplay,
    data: FungibleTokenMetadataViews.FTVaultData
): FTVaultInfo {
    let identifier = vaultType.identifier
    let addrString = "0x".concat(identifier.split(separator: ".")[1])
    let contractAddress = Address.fromString(addrString) ?? panic("INVALID ADDRESS: ".concat(addrString))
    let contractName = identifier.split(separator: ".")[2]

    return FTVaultInfo(
        name: display.name,
        symbol: display.symbol,
        balance: balance,
        tokenContractAddress: contractAddress,
        tokenContractName: contractName,
        storagePath: data.storagePath,
        receiverPath: data.receiverPath
    )
}

access(all)
fun main(address: Address): {Type: FTVaultInfo} {
    let acct = getAuthAccount<auth(BorrowValue) &Account>(address)
    let res: {Type: FTVaultInfo} = {}

    // Define target types
    let ftVaultType = Type<@{FungibleToken.Vault}>()
    let displayType = Type<FungibleTokenMetadataViews.FTDisplay>()
    let dataType = Type<FungibleTokenMetadataViews.FTVaultData>()

    acct.storage.forEachStored(fun (path: StoragePath, type: Type): Bool {
        if type.isSubtype(of: ftVaultType) {
            // Reference the Vault at the current storage path
            let vault = acct.storage.borrow<&{FungibleToken.Vault}>(from: path)
                ?? panic("Problem borrowing vault from path: ".concat(path.toString()))
            // Get the balance
            var balance = vault.balance
            // Update the balance if the Vault type has already been encountered & return early
            if let info = res[type] {
                info.updateBalance(delta: balance)
                return true
            }

            // Resolve FT metadata views
            let display = vault.resolveView(displayType) as! FungibleTokenMetadataViews.FTDisplay?
            let data = vault.resolveView(dataType) as! FungibleTokenMetadataViews.FTVaultData?
            // Continue if metadata views are not resolved - no relevant info to capture
            if display == nil || data == nil {
                return true
            }
            // Capture the relevant info and insert to our result mapping
            let info = getVaultInfo(vaultType: type, balance: balance, display: display!, data: data!)
            res.insert(key: type, info)
        }
        return true
    })
    return res
}