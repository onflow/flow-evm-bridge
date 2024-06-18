import "FlowEVMBridgeConfig"

access(all)
fun main(typeIdentifier: String): Bool? {
    return FlowEVMBridgeConfig.isTypePaused(
        CompositeType(typeIdentifier) ?? panic("Invalid type identifier provided: ".concat(typeIdentifier))
    )
}
