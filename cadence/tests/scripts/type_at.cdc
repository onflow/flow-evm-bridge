access(all)
fun main(addr: Address, sp: StoragePath): Type? {
    return getAuthAccount<auth(BorrowValue) &Account>(addr).storage.type(at: sp)
}
