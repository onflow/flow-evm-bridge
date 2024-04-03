import "EVMBridgeRouter"

access(all)
fun main(): Bool {
    let serviceAccount = getAuthAccount<auth(Storage) &Account>(0x0000000000000001)
    let router = serviceAccount.storage.borrow<&EVMBridgeRouter.Router>(
        from: /storage/evmBridgeRouter
    ) ?? panic("Could not borrow Router")

    assert(router.bridgeAddress == 0x0000000000000007)
    assert(router.bridgeContractName == "FlowEVMBridge")

    return true
}
