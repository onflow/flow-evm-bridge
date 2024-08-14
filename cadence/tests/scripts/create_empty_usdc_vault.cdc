import "USDCFlow"

access(all)
fun main() {
    let v <- USDCFlow.createEmptyVault(vaultType: Type<@USDCFlow.Vault>())
    log("Vault creation successful")
    destroy v
}
