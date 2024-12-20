import "EVM"

import "FlowEVMBridgeConfig"

/// Blocks the given Cadence Type from onboarding.
///
/// @param typeIdentifier: The Cadence identifier of the type to block
///
transaction(typeIdentifier: String) {

    let cadenceBlocklist: auth(FlowEVMBridgeConfig.Blocklist) &FlowEVMBridgeConfig.CadenceBlocklist
    let type: Type

    prepare(signer: auth(BorrowValue) &Account) {
        self.cadenceBlocklist = signer.storage.borrow<auth(FlowEVMBridgeConfig.Blocklist) &FlowEVMBridgeConfig.CadenceBlocklist>(
                from: /storage/cadenceBlocklist
            ) ?? panic("Could not borrow FlowEVMBridgeConfig Admin reference")
        self.type = CompositeType(typeIdentifier) ?? panic("Invalid type identifier ".concat(typeIdentifier))
    }

    execute {
        self.cadenceBlocklist.block(self.type)
    }

    post {
        FlowEVMBridgeConfig.isCadenceTypeBlocked(self.type): "Type was not blocked"
    }
}
