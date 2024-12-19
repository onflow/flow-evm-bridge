import "FlowEVMBridgeConfig"

transaction {
    prepare(signer: &Account) {}

    execute {
        FlowEVMBridgeConfig.initCadenceBlocklist()       
    }
}