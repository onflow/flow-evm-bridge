import "NonFungibleToken"
import "MetadataViews"

import "FlowEVMBridgeNFTEscrow"
import "FlowEVMBridgeUtils"

/// Resolves the view for the requested locked NFT or nil if the NFT is not locked
/// NOTE: This functionality is not available via the escrow contract as `resolveView` is not a `view` method, but the
///     escrow contract
///
/// @param bridgeAddress: The address of the bridge contract (included as the VM bridge address varies across networks)
/// @param nftTypeIdentifier: The identifier of the NFT type
/// @param id: The ERC721 id of the escrowed NFT
/// @param viewIdentifier: The identifier of the view to resolve
///
/// @return The resolved view if the NFT is escrowed & the view is resolved by it or nil if the NFT is not locked
///
access(all) fun main(bridgeAddress: Address, nftTypeIdentifier: String, id: UInt256, viewIdentifier: String): AnyStruct? {
    // Construct runtime types from provided identifiers
    let nftType: Type = CompositeType(nftTypeIdentifier) ?? panic("Malformed NFT type identifier=".concat(nftTypeIdentifier))
    let view: Type = CompositeType(viewIdentifier) ?? panic("Malformed view type identifier=".concat(viewIdentifier))

    // Derive the Locker path for the given NFT type
    let lockerPath = FlowEVMBridgeUtils.deriveEscrowStoragePath(fromType: nftType)
        ?? panic("Problem deriving Locker path for NFT type identifier=".concat(nftTypeIdentifier))

    // Borrow the locker from the bridge account's storage
    if let locker = getAuthAccount<auth(BorrowValue) &Account>(bridgeAddress).storage.borrow<&FlowEVMBridgeNFTEscrow.Locker>(
        from: lockerPath
    ) {
        // Retrieve the NFT type's cadence ID from the locker
        if let cadenceID = locker.getCadenceID(from: id) {
            // Resolve the requested view for the given NFT type, returning nil if the view is not supported or the NFT
            // is not locked in escrow
            return locker.borrowViewResolver(id: cadenceID)?.resolveView(view)
        }
    }

    // Return nil if no locker was found for the given NFT type
    return nil
}
