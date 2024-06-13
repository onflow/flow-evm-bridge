import "EVM"

access(all)
fun main(hex: String): EVM.EVMAddress? {
    return EVM.addressFromString(hex)
}