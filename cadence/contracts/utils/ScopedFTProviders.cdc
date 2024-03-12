import "FungibleToken"
import "StringUtils"

// Copied from https://github.com/green-goo-dao/flow-utils/blob/crescendo/contracts/ScopedFTProviders.cdc with minor changes
//
// ScopedFTProviders
//
// TO AVOID RISK, PLEASE DEPLOY YOUR OWN VERSION OF THIS CONTRACT SO THAT
// MALICIOUS UPDATES ARE NOT POSSIBLE
//
// ScopedProviders are meant to solve the issue of unbounded access FungibleToken vaults
// when a provider is called for.
access(all) contract ScopedFTProviders {
    access(all) struct interface FTFilter {
        access(all) view fun canWithdrawAmount(_ amount: UFix64): Bool
        access(FungibleToken.Withdraw) fun markAmountWithdrawn(_ amount: UFix64)
        access(all) fun getDetails(): {String: AnyStruct}
    }

    access(all) struct AllowanceFilter: FTFilter {
        access(self) let allowance: UFix64
        access(self) var allowanceUsed: UFix64

        init(_ allowance: UFix64) {
            self.allowance = allowance
            self.allowanceUsed = 0.0
        }

        access(all) view fun canWithdrawAmount(_ amount: UFix64): Bool {
            return amount + self.allowanceUsed <= self.allowance
        }

        access(FungibleToken.Withdraw) fun markAmountWithdrawn(_ amount: UFix64) {
            self.allowanceUsed = self.allowanceUsed + amount
        }

        access(all) fun getDetails(): {String: AnyStruct} {
            return {
                "allowance": self.allowance,
                "allowanceUsed": self.allowanceUsed
            }
        }
    }

    // ScopedFTProvider
    //
    // A ScopedFTProvider is a wrapped FungibleTokenProvider with
    // filters that can be defined by anyone using the ScopedFTProvider.
    access(all) resource ScopedFTProvider: FungibleToken.Provider {
        access(self) let provider: Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>
        access(self) var filters: [{FTFilter}]

        // block timestamp that this provider can no longer be used after
        access(self) let expiration: UFix64?

        access(all) init(provider: Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>, filters: [{FTFilter}], expiration: UFix64?) {
            pre {
                provider.check(): "Invalid Provider Capability"
            }
            self.provider = provider
            self.filters = filters
            self.expiration = expiration
        }

        access(all) fun check(): Bool {
            return self.provider.check()
        }

        access(all) view fun isExpired(): Bool {
            if let expiration = self.expiration {
                return getCurrentBlock().timestamp >= expiration
            }
            return false
        }

        access(all) view fun canWithdraw(_ amount: UFix64): Bool {
            if self.isExpired() {
                return false
            }

            for filter in self.filters {
                if !filter.canWithdrawAmount(amount) {
                    return false
                }
            }

            return true
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return self.canWithdraw(amount)
        }

        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                !self.isExpired(): "provider has expired"
            }

            var i = 0
            while i < self.filters.length {
                if !self.filters[i].canWithdrawAmount(amount) {
                    panic(StringUtils.join(["cannot withdraw tokens. filter of type", self.filters[i].getType().identifier, "failed."], " "))
                }

                self.filters[i].markAmountWithdrawn(amount)
                i = i + 1
            }

            return <-self.provider.borrow()!.withdraw(amount: amount)
        }

        access(all) fun getDetails(): [{String: AnyStruct}] {
            let details: [{String: AnyStruct}] = []
            for filter in self.filters {
                details.append(filter.getDetails())
            }

            return details
        }
    }

    access(all) fun createScopedFTProvider(
        provider: Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>,
        filters: [{FTFilter}],
        expiration: UFix64?
    ): @ScopedFTProvider {
        return <- create ScopedFTProvider(provider: provider, filters: filters, expiration: expiration)
    }
}
