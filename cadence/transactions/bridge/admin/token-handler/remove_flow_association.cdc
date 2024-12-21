import "FlowToken"

import "EVM"

import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeConfig"

/// Removes the FlowToken.Vault association with the EVM origination address. This is intended for use in making way
/// for the bridge to handle FlowToken.Vault requests using FlowEVMBridgeHandlers.WFLOWTokenHandler
///
transaction {

    let preAssociation: EVM.EVMAddress
    let admin: auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeConfig.Admin
    var removedAssociation: EVM.EVMAddress?

    prepare(signer: auth(BorrowValue, LoadValue) &Account) {
        self.preAssociation = FlowEVMBridgeConfig.getEVMAddressAssociated(with: Type<@FlowToken.Vault>())
            ?? panic("No EVM address associated with FlowToken Vault - nothing to remove")
        self.removedAssociation = nil
        self.admin = signer.storage.borrow<auth(FlowEVMBridgeHandlerInterfaces.Admin) &FlowEVMBridgeConfig.Admin>(
                from: FlowEVMBridgeConfig.adminStoragePath
            ) ?? panic("Missing or mistyped FlowEVMBridgeConfig.Admin")
    }

    execute {
        self.removedAssociation = self.admin.removeAssociationByType(Type<@FlowToken.Vault>())
    }

    post {
        self.preAssociation.equals(self.removedAssociation!):
        "Mismatched EVM addresses - expected: ".concat(self.preAssociation.toString())
            .concat(", actual: ").concat(self.removedAssociation?.toString() ?? "nil")
    }
}
