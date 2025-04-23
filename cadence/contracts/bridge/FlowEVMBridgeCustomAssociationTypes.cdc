import "FungibleToken"
import "NonFungibleToken"
import "CrossVMMetadataViews"
import "EVM"

/// This contract defines types required for custom cross-VM associations as used in FlowEVMBridgeCustomAssociation
/// and in EVM-native cross-VM NFTs.
///
access(all) contract FlowEVMBridgeCustomAssociationTypes {

    /// Emitted whenever an NFTFulfillmentMinter is used to fulfill an NFT from EVM
    access(all) event FulfilledFromEVM(type: String, requestedID: UInt256, resultID: UInt64, uuid: UInt64)

    access(all) entitlement FulfillFromEVM

    /// Resource interface used by EVM-native NFT collections allowing for the fulfillment of NFTs from EVM into Cadence
    ///
    access(all) resource interface NFTFulfillmentMinter {
        /// Getter for the type of NFT that's fulfilled by this implementation
        ///
        access(all) view fun getFulfilledType(): Type

        /// Called by the VM bridge when moving NFTs from EVM into Cadence if the NFT is not in escrow. Since such NFTs
        /// are EVM-native, they are distributed in EVM. On the Cadence side, those NFTs are handled by a mint & escrow
        /// pattern. On moving to EVM, the NFTs are minted if not in escrow at the time of bridging.
        ///
        /// @param id: The id of the token being fulfilled from EVM
        ///
        /// @return The NFT fulfilled from EVM as its Cadence implementation
        ///
        access(FulfillFromEVM)
        fun fulfillFromEVM(id: UInt256): @{NonFungibleToken.NFT} {
            pre {
                id <= UInt256(UInt64.max):
                "The requested ID \(id.toString()) exceeds the maximum assignable Cadence NFT ID \(UInt64.max.toString())"
            }
            post {
                UInt256(result.id) == id:
                "Resulting NFT ID \(result.id.toString()) does not match requested ID \(id.toString())"
                result.getType() == self.getFulfilledType():
                "Expected \(self.getFulfilledType().identifier) but fulfilled \(result.getType().identifier)"
                emit FulfilledFromEVM(type: result.getType().identifier, requestedID: id, resultID: result.id, uuid: result.uuid)
            }
        }
    }

    /// Data structure containing information about a registered CustomConfig
    ///
    access(all) struct CustomConfigInfo {
        access(all) let updatedFromBridged: Bool
        access(all) let isPaused: Bool
        access(all) let fulfillmentMinterType: Type?
        access(all) let evmPointer: CrossVMMetadataViews.EVMPointer
        
        view init(
            updatedFromBridged: Bool,
            isPaused: Bool,
            fulfillmentMinterType: Type?,
            evmPointer: CrossVMMetadataViews.EVMPointer
        ) {
            self.updatedFromBridged = updatedFromBridged
            self.isPaused = isPaused
            self.fulfillmentMinterType = fulfillmentMinterType
            self.evmPointer = evmPointer
        }
    }

    /// Resource interface retrieving all relevant information for the VM bridge to fulfill bridge requests. The
    /// interface allows for extensibility in the event future config types are added in the future for various asset
    /// types.
    ///
    access(all) resource interface CustomConfig {
        access(all) view fun getCadenceType(): Type
        access(all) view fun getCadenceStandardInterfaceTypes(): {Type: Bool}
        access(all) view fun getEVMContractAddress(): EVM.EVMAddress
        access(all) view fun getNativeVM(): CrossVMMetadataViews.VM
        access(all) view fun isUpdatedFromBridged(): Bool
        access(all) view fun isPaused(): Bool
        access(all) view fun checkFulfillmentMinter(): Bool?
        access(account) fun setPauseStatus(_ paused: Bool)
    }

    /// Resource containing all relevant information for the VM bridge to fulfill NFT bridge requests. This is a resource
    /// instead of a struct to ensure contained Capabilities cannot be copied
    ///
    access(all) resource NFTCustomConfig : CustomConfig  {
        /// The Cadence Type of the associated asset.
        access(all) let type: Type
        /// The EVM address defining the EVM implementation of the associated asset.
        access(all) let evmContractAddress: EVM.EVMAddress
        /// The VM in which the asset is distributed by the project. The bridge will mint/escrow in the non-native
        /// VM environment.
        access(all) let nativeVM: CrossVMMetadataViews.VM
        /// Whether the asset was originally onboarded to the bridge via permissionless onboarding. In other words,
        /// whether there was first a bridge-defined implementation of the underlying asset.
        access(all) let updatedFromBridged: Bool
        /// Flag determining if this config is paused from bridging - true: paused | false: unpaused
        access(all) var pauseStatus: Bool
        /// An authorized Capability allowing the bridge to fulfill bridge requests moving the underlying asset from
        /// EVM. Required if the asset is EVM-native.
        access(self) let fulfillmentMinter: Capability<auth(FulfillFromEVM) &{NFTFulfillmentMinter}>?

        init(
            type: Type,
            evmContractAddress: EVM.EVMAddress,
            nativeVM: CrossVMMetadataViews.VM,
            updatedFromBridged: Bool,
            fulfillmentMinter: Capability<auth(FulfillFromEVM) &{NFTFulfillmentMinter}>?
        ) {
            pre {
                type.isSubtype(of: Type<@{NonFungibleToken.NFT}>()):
                "The provided Type \(type.identifier) is not an NFT implementation - only NFTs are supported by NFTCustomConfig"
                nativeVM == CrossVMMetadataViews.VM.EVM ? fulfillmentMinter != nil : true:
                "EVM-native NFTs must provide an NFTFulfillmentMinter Capability."
                fulfillmentMinter?.check() ?? true:
                "Invalid NFTFulfillmentMinter Capability provided. Ensure the Capability is properly issued and active."
                fulfillmentMinter != nil ? fulfillmentMinter!.borrow()!.getFulfilledType() == type : true:
                "NFTFulfillmentMinter fulfills \(fulfillmentMinter!.borrow()!.getFulfilledType().identifier) but expected \(type.identifier)"
            }
            self.type = type
            self.evmContractAddress = evmContractAddress
            self.nativeVM = nativeVM
            self.updatedFromBridged = updatedFromBridged
            self.pauseStatus = false
            self.fulfillmentMinter = fulfillmentMinter
        }

        /// Returns the Cadence Type related to this custom cross-VM NFT configuration
        access(all) view fun getCadenceType(): Type {
            return self.type
        }

        /// Returns the Cadence standard Types supported by this CustomConfig implementation
        access(all) view fun getCadenceStandardInterfaceTypes(): {Type: Bool} {
            return {Type<@{NonFungibleToken.NFT}>(): true}
        }

        /// Returns the EVM contract address related to this custom cross-VM NFT configuration
        access(all) view fun getEVMContractAddress(): EVM.EVMAddress {
            return self.evmContractAddress
        }

        /// Returns the VM in which the NFT is distributed
        access(all) view fun getNativeVM(): CrossVMMetadataViews.VM {
            return self.nativeVM
        }

        /// True if the NFT was originally onboarded to the bridge 
        access(all) view fun isUpdatedFromBridged(): Bool {
            return self.updatedFromBridged
        }

        /// True if currently paused, false if unpaused
        access(all) view fun isPaused(): Bool {
            return self.pauseStatus
        }

        /// Returns true/false on the fulfillment minter Capability. If no Capability is stored, nil is returned
        access(all) view fun checkFulfillmentMinter(): Bool? {
            return self.fulfillmentMinter?.check() ?? nil
        }

        /// Returns a reference to the NFTFulfillmentMinter, allowing the bridge contracts to fulfill EVM-native NFTs
        /// moving into Cadence
        access(account)
        view fun borrowFulfillmentMinter(): auth(FulfillFromEVM) &{NFTFulfillmentMinter} {
            pre  {
                self.fulfillmentMinter != nil:
                "CustomConfig for type \(self.type.identifier) was not assigned a NFTFulfillmentMinter."
            }
            return self.fulfillmentMinter!.borrow()
                ?? panic("NFTFulfillmentMinter for type \(self.type.identifier) is now invalid.")
        }

        access(account) fun setPauseStatus(_ paused: Bool) {
            self.pauseStatus = paused
        }
    }

    /// Allows bridge contracts to create an NFTCustomConfig resource from the provided arguments
    access(account)
    fun createNFTCustomConfig(
        type: Type,
        evmContractAddress: EVM.EVMAddress,
        nativeVM: CrossVMMetadataViews.VM,
        updatedFromBridged: Bool,
        fulfillmentMinter: Capability<auth(FulfillFromEVM) &{NFTFulfillmentMinter}>?
    ): @NFTCustomConfig {
        return <- create NFTCustomConfig(
            type: type,
            evmContractAddress: evmContractAddress,
            nativeVM: nativeVM,
            updatedFromBridged: updatedFromBridged,
            fulfillmentMinter: fulfillmentMinter
        )
    }
}