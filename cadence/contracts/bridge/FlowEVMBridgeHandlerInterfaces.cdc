import "FungibleToken"
import "NonFungibleToken"

import "EVM"

access(all) contract FlowEVMBridgeHandlerInterfaces {

    // Entitlement related to admin-like functionality
    access(all) entitlement Admin
    access(all) entitlement Mint

    // Events
    //
    access(all) event HandlerEnabled(handlerType: Type, targetType: Type, targetEVMAddress: EVM.EVMAddress)

    access(all) resource interface HandlerInfo {
        access(all)	view fun isEnabled(): Bool
        access(all) view fun getTargetType(): Type?
        access(all) view fun getTargetEVMAddress(): EVM.EVMAddress?
    }

    access(all) resource interface HandlerAdmin : HandlerInfo {
        access(Admin) fun setTargetType(_ type: Type) {
            pre {
                self.getTargetType() == nil: "Target Type has already been set"
            }
            post {
                self.getTargetType()! == type: "Problem setting target type"
            }
        }
        access(Admin) fun setTargetEVMAddress(_ address: EVM.EVMAddress) {
            pre {
                self.getTargetEVMAddress() != nil: "Target EVM address has already been set"
            }
            post {
                self.getTargetEVMAddress()!.bytes == address!.bytes: "Problem setting target EVM address"
            }
        }
        access(Admin) fun enableBridging() {
            pre {
                self.getTargetType() != nil && self.getTargetEVMAddress() != nil:
                    "Cannot enable before setting bridge targets"
                !self.isEnabled(): "Handler already enabled"
            }
            post {
                self.isEnabled(): "Problem enabling Handler"
                emit HandlerEnabled(
                    handlerType: self.getType(),
                    targetType: self.getTargetType()!,
                    targetEVMAddress: self.getTargetEVMAddress()!
                )
            }
        }
    }

    access(all) resource interface TokenMinter {
        access(all) view fun getMintedType(): Type
        access(Mint) fun mint(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                amount > 0.0: "Amount must be greater than 0"
            }
            post {
                result.getType() == self.getMintedType(): "Invalid Vault type returned"
                result.balance == amount: "Minted amount does not match requested amount"
            }
        }
    }

    access(all) resource interface TokenHandler : HandlerInfo, HandlerAdmin {
        // Handling
        //
        access(account) fun fulfillTokensToEVM(
            tokens: @{FungibleToken.Vault},
            to: EVM.EVMAddress
        ) {
            pre {
                self.isEnabled(): "Handler is not yet enabled"
                tokens.getType() == self.getTargetType(): "Invalid Vault type"
            }
        }
        access(account) fun fulfillTokensFromEVM(
            owner: EVM.EVMAddress,
            type: Type,
            amount: UInt256,
            protectedTransferCall: fun (): EVM.Result
        ): @{FungibleToken.Vault} {
            pre {
                self.isEnabled(): "Handler is not yet enabled"
            }
            post {
                result.getType() == self.getTargetType(): "Invalid Vault type returned"
            }
        }
    }
}
