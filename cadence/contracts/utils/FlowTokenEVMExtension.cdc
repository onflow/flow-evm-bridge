import "FlowToken"
import "FungibleToken"

import "EVM"

access(all) contract FlowTokenEVMExtension {

    access(all) attachment FlowTokenEVMVaultAttachment for FlowToken.Vault {
        access(self) let evmVault: @FlowTokenEVMVault

        init(targetCOACap: Capability<auth(EVM.Withdraw) &EVM.CadenceOwnedAccount>) {
            self.evmVault <-create FlowTokenEVMVault(targetCOACap)
        }
    }

    access(all) resource FlowTokenEVMVault : FungibleToken.Receiver, FungibleToken.Provider {
        access(self) let coaCapability: Capability<auth(EVM.Withdraw) &EVM.CadenceOwnedAccount>

        init(_ cap: Capability<auth(EVM.Withdraw) &EVM.CadenceOwnedAccount>) {
            pre {
                cap.check(): "Invalid COA Capability"
            }
            self.coaCapability = cap
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            self._borrowCOA().deposit(from: <-from)
        }

        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return { Type<@FlowToken.Vault>(): true }
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return self._borrowCOA().balance.toFLOW() >= amount
        }

        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            return <-self._borrowCOA().withdraw(amount: amount)
        }

        access(self) view fun _borrowCOA(): auth(EVM.Withdraw) &EVM.CadenceOwnedAccount {
            return self.coaCapability.borrow() ?? panic("Invalid COA Capability")
        }
    }
}
