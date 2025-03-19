import "CrossVMMetadataViews"

import "FlowEVMBridgeUtils"

access(all)
fun main(nftTypeIdentifier: String): CrossVMMetadataViews.EVMPointer? {
    if let nftType = CompositeType(nftTypeIdentifier) {
        return FlowEVMBridgeUtils.getEVMPointerView(forType: nftType)
    }
    return nil
}
