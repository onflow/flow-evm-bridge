import "FlowEVMBridgeTemplates"

access(all) fun main(identifier: String): String? {
    if let type = CompositeType(identifier) {
        if let contractBytes = FlowEVMBridgeTemplates.getLockerContractCode(forType: type) {
            return String.fromUTF8(contractBytes)
        }
    }
    return nil
}
