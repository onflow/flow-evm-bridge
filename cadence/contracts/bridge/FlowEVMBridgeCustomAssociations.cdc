import "NonFungibleToken"
import "CrossVMMetadataViews"
import "EVM"

/// The FlowEVMBridgeCustomAssociations is tasked with preserving custom associations between Cadence assets and their
/// EVM implementations. These associations should be validated before `saveCustomAssociation` is called by
/// leveraging the interfaces outlined in FLIP-318 (https://github.com/onflow/flips/issues/318) to ensure that the
/// declared association is valid and that neither implementation is bridge-defined.
///
access(all) contract FlowEVMBridgeCustomAssociations {

    /// Stored associations indexed by Cadence Type
    access(self) let associationsConfig: @{Type: CustomConfig}
    /// Reverse lookup indexed on serialized EVM contract address
    access(self) let associationsByEVMAddress: {String: Type}

    /// Event emitted whenever a custom association is established
    access(all) event CustomAssociationEstablished(
        type: Type,
        evmContractAddress: String,
        nativeVMRawValue: UInt8,
        updatedFromBridged: Bool,
        fulfillmentMinterType: String?,
        fulfillmentMinterOrigin: Address?,
        fulfillmentMinterCapID: UInt64?,
        fulfillmentMinterUUID: UInt64?,
        configUUID: UInt64
    )

    access(all)
    view fun getEVMAddressAssociated(with type: Type): EVM.EVMAddress? {
        return self.associationsConfig[type]?.getEVMContractAddress() ?? nil
    }

    access(all)
    view fun getTypeAssociated(with evmAddress: EVM.EVMAddress): Type? {
        return self.associationsByEVMAddress[evmAddress.toString()]
    }

    access(all)
    fun getEVMPointerAsRegistered(forType: Type): CrossVMMetadataViews.EVMPointer? {
        if let config = &self.associationsConfig[forType] as &CustomConfig? {
            return CrossVMMetadataViews.EVMPointer(
                cadenceType: config.getCadenceType(),
                cadenceContractAddress: config.getCadenceType().address!,
                evmContractAddress: config.getEVMContractAddress(),
                nativeVM: config.getNativeVM()
            )
        }
        return nil
    }

    /// Allows the bridge contracts to preserve a custom association. Will revert if a custom association already exists
    ///
    /// @param type: The Cadence Type of the associated asset.
    /// @param evmContractAddress: The EVM address defining the EVM implementation of the associated asset.
    /// @param nativeVM: The VM in which the asset is distributed by the project. The bridge will mint/escrow in the non-native
    ///     VM environment.
    /// @param updatedFromBridged: Whether the asset was originally onboarded to the bridge via permissionless
    ///     onboarding. In other words, whether there was first a bridge-defined implementation of the underlying asset.
    /// @param fulfillmentMinter: An authorized Capability allowing the bridge to fulfill bridge requests moving the
    ///     underlying asset from EVM. Required if the asset is EVM-native.
    ///
    access(account)
    fun saveCustomAssociation(
        type: Type,
        evmContractAddress: EVM.EVMAddress,
        nativeVM: CrossVMMetadataViews.VM,
        updatedFromBridged: Bool,
        fulfillmentMinter: Capability<auth(FulfillFromEVM) &{NFTFulfillmentMinter}>?
    ) {
        pre {
            self.associationsConfig[type] == nil:
            "Type ".concat(type.identifier).concat(" already has a custom association with ")
                .concat(self.borrowCustomConfig(forType: type)!.evmContractAddress.toString())
            self.associationsByEVMAddress[evmContractAddress.toString()] == nil:
            "EVM Address ".concat(evmContractAddress.toString()).concat(" already has a custom association with ")
                .concat(self.borrowCustomConfig(forType: type)!.type.identifier)
            fulfillmentMinter?.check() ?? true:
            "The NFTFulfillmentMinter Capability issued from ".concat(fulfillmentMinter!.address.toString())
                .concat(" is invalid. Ensure the Capability is properly issued and active.")
        }
        let config <- create CustomConfig(
                type: type,
                evmContractAddress: evmContractAddress,
                nativeVM: nativeVM,
                updatedFromBridged: updatedFromBridged,
                fulfillmentMinter: fulfillmentMinter
            )
        emit CustomAssociationEstablished(
            type: type,
            evmContractAddress: evmContractAddress.toString(),
            nativeVMRawValue: nativeVM.rawValue,
            updatedFromBridged: updatedFromBridged,
            fulfillmentMinterType: fulfillmentMinter != nil ? fulfillmentMinter!.borrow()!.getType().identifier : nil,
            fulfillmentMinterOrigin: fulfillmentMinter?.address ?? nil,
            fulfillmentMinterCapID: fulfillmentMinter?.id ?? nil,
            fulfillmentMinterUUID: fulfillmentMinter != nil ? fulfillmentMinter!.borrow()!.uuid : nil,
            configUUID: config.uuid
        )
        self.associationsByEVMAddress[config.evmContractAddress.toString()] = type
        self.associationsConfig[type] <-! config
    }

    access(all) entitlement FulfillFromEVM

    /// Resource interface used by EVM-native NFT collections allowing for the fulfillment of NFTs from EVM into Cadence
    ///
    access(all) resource interface NFTFulfillmentMinter {
        /// Getter for the type of NFT that's fulfilled by this implementation
        ///
        access(all)
        view fun getFulfilledType(): Type

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
                id < UInt256(UInt64.max):
                "The requested ID ".concat(id.toString())
                    .concat(" exceeds the maximum assignable Cadence NFT ID ").concat(UInt64.max.toString())
            }
            post {
                UInt256(result.id) == id:
                "Resulting NFT ID ".concat(result.id.toString())
                    .concat(" does not match requested ID ").concat(id.toString())
                result.getType() == self.getFulfilledType():
                "Expected ".concat(self.getFulfilledType().identifier).concat(" but fulfilled ")
                    .concat(result.getType().identifier)
            }
        }
    }

    /// Resource containing all relevant information for the VM bridge to fulfill bridge requests. This is a resource
    /// instead of a struct to ensure contained Capabilities cannot be copied
    ///
    access(all) resource CustomConfig {
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
                nativeVM == CrossVMMetadataViews.VM.EVM ? fulfillmentMinter != nil : true:
                "EVM-native NFTs must provide an NFTFulfillmentMinter Capability."
                fulfillmentMinter?.check() ?? true:
                "Invalid NFTFulfillmentMinter Capability provided. Ensure the Capability is properly issued and active."
                fulfillmentMinter != nil ? fulfillmentMinter!.borrow()!.getFulfilledType() == type : true:
                "NFTFulfillmentMinter fulfills ".concat(fulfillmentMinter!.borrow()!.getFulfilledType().identifier)
                    .concat(" but expected ").concat(type.identifier)
            }
            self.type = type
            self.evmContractAddress = evmContractAddress
            self.nativeVM = nativeVM
            self.updatedFromBridged = updatedFromBridged
            self.fulfillmentMinter = fulfillmentMinter
        }

        access(all)
        view fun check(): Bool? {
            return self.fulfillmentMinter?.check() ?? nil
        }

        access(all)
        view fun getCadenceType(): Type {
            return self.type
        }

        access(all)
        view fun getEVMContractAddress(): EVM.EVMAddress {
            return self.evmContractAddress
        }

        access(all)
        view fun getNativeVM(): CrossVMMetadataViews.VM {
            return self.nativeVM
        }

        access(all)
        view fun isUpdatedFromBridged(): Bool {
            return self.updatedFromBridged
        }

        access(account)
        view fun borrowFulfillmentMinter(): auth(FulfillFromEVM) &{NFTFulfillmentMinter} {
            pre  {
                self.fulfillmentMinter != nil:
                "CustomConfig for type ".concat(self.type.identifier)
                    .concat(" was not assigned a NFTFulfillmentMinter.")
            }
            return self.fulfillmentMinter!.borrow()
                ?? panic("NFTFulfillmentMinter for type ".concat(self.type.identifier).concat(" is now invalid."))
        }
    }

    /// Returns a reference to the CustomConfig if it exists, nil otherwise
    ///
    access(self)
    view fun borrowCustomConfig(forType: Type): &CustomConfig? {
        return &self.associationsConfig[forType]
    }


    init() {
        self.associationsConfig <- {}
        self.associationsByEVMAddress = {}
    }
}
