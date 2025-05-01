import "EVM"
import "FungibleToken"
import "FlowEVMBridgeUtils"
import "FlowEVMBridgeConfig"
import "FungibleTokenMetadataViews"

/// Returns the balance of the owner of a given Fungible Token
/// from their Cadence account and their COA
///
/// @param owner: The Flow address of the owner
/// @param contractAddress: The address of the FT contract in Cadence
/// @param contractName: The name of the FT contract in Cadence
///
/// @return The balance of the address, reverting if the given contract address does not implement the ERC20 method
///     "balanceOf(address)(uint256)"
///

access(all) fun main(owner: Address, contractAddress: Address, contractName: String): UInt256 {
    // Borrow a reference to the FT contract
    let resolverRef = getAccount(contractAddress)
        .contracts.borrow<&{FungibleToken}>(name: contractName)
            ?? panic("Could not borrow FungibleToken reference to the contract. Make sure the provided contract name ("
                        .concat(contractName).concat(") and address (").concat(contractAddress.toString()).concat(") are correct!"))

    // Use that reference to retrieve the FTView 
    let vaultData = resolverRef.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("Could not resolve FTVaultData view. The ".concat(contractName)
            .concat(" contract needs to implement the FTVaultData Metadata view in order to execute this transaction."))

    // Get the Cadence balance of the token
    let cadenceBalance = getAccount(owner).capabilities.borrow<&{FungibleToken.Balance}>(
            vaultData.metadataPath
        )?.balance
        ?? panic("Could not borrow a balance reference to the FungibleToken Vault in account "
                .concat(owner.toString()).concat(" at path ").concat(vaultData.metadataPath.toString())
                .concat(". Make sure you are querying an address that has ")
                .concat("a FungibleToken Vault set up properly at the specified path."))

    // Get the COA from the owner's account
    let coa = getAuthAccount<auth(BorrowValue) &Account>(owner)
        .storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA from provided address")
    // Get the COA address
    let coaAddress = coa.address().toString()

    let contractAddressWithoutHexPrefix = contractAddress.toString().slice(from: 2, upTo: 18)

    // Get the EVM address of the bridged version of the Cadence FT contract
    let typeIdentifier = "A.\(contractAddressWithoutHexPrefix).\(contractName).Vault"
    var tokenEVMAddress = ""
    if let type = CompositeType(typeIdentifier) {
        if let address = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) {
            tokenEVMAddress = address.toString()
        } else {
            panic("Could not get an EVM address from the provided type")
        }
    } else {
        panic("Could not construct type with \(typeIdentifier)")
    }

    // Get the ERC20 balance of the COA
    let coaBalance = FlowEVMBridgeUtils.balanceOf(
        owner: EVM.addressFromString(coaAddress),
        evmContractAddress: EVM.addressFromString(tokenEVMAddress)
    )

    // Get the token decimals of the ERC20 contract
    let decimals = FlowEVMBridgeUtils.getTokenDecimals(
        evmContractAddress: EVM.addressFromString(tokenEVMAddress)
    )
    // Convert the Cadence balance to UInt256
    let cadenceBalanceUInt256 = FlowEVMBridgeUtils.ufix64ToUInt256(value: cadenceBalance, decimals: decimals)

    return coaBalance + cadenceBalanceUInt256
}