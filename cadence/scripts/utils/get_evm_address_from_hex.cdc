import "EVM"

import "EVMUtils"

access(all)
fun main(hex: String): EVM.EVMAddress? {
    return EVMUtils.getEVMAddressFromHexString(address: hex)
}