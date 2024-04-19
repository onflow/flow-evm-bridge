import "FungibleToken"
import "NonFungibleToken"

import "EVM"

access(all) contract FlowEVMBridgeHandlers {
    
    // Entitlement related to admin-like functionality
    access(all) entitlement Admin

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
                self.getTargetType() != nil: "Target Type has already been set"
            }
        }
        access(Admin) fun setTargetEVMAddress(_ address: EVM.EVMAddress) {
            pre {
                self.getTargetEVMAddress() != nil: "Target EVM address has already been set"
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
    
    access(all) resource interface FTHandler : HandlerInfo, HandlerAdmin {
        // Handling
        //
        access(EVM.Bridge) fun fulfillTokensToEVM(
            tokens: @{FungibleToken.Vault},
            to: EVM.EVMAddress
        ) {
            pre {
                self.isEnabled(): "Handler is not yet enabled"
                tokens.getType() == self.getTargetType(): "Invalid Vault type"
            }
        }
        access(EVM.Bridge) fun fulfillTokensFromEVM(
            owner: EVM.EVMAddress,
            type: Type,
            amount: UFix64,
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

    access(all) resource interface NFTHandler : HandlerInfo, HandlerAdmin {
        // Handling
        //
        access(EVM.Bridge) fun fulfillNFTToEVM(
            nft: @{NonFungibleToken.NFT},
            to: EVM.EVMAddress
        ) {
            pre {
                self.isEnabled(): "Handler is not yet enabled"
                nft.getType() == self.getTargetType(): "Invalid Vault type"
            }
        }
        access(EVM.Bridge) fun fulfillNFTFromEVM(
            owner: EVM.EVMAddress,
            type: Type,
            amount: UFix64,
            protectedTransferCall: fun (): EVM.Result
        ): @{NonFungibleToken.NFT} {
            pre {
                self.isEnabled(): "Handler is not yet enabled"
            }
            post {
                result.getType() == self.getTargetType(): "Invalid Vault type returned"
            }
        }
    }
}
