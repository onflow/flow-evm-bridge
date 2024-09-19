import "EVM"

import "FlowEVMBridgeConfig"

///  Initializes the EVMBlocklist in the bridge account if it does not yet exist at the expected path
///
transaction {

    prepare(signer: &Account) {}

    execute {
        FlowEVMBridgeConfig.initBlocklist()
    }
}
