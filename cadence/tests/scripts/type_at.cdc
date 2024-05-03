access(all)
fun main(addr: Address, sp: StoragePath): Type? {
    return getAuthAccount<auth(BorrowValue) &Account>(addr).storage.borrow<&AnyResource>(from: sp)?.getType() ?? nil
}