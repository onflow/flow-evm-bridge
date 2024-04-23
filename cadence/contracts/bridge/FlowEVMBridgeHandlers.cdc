import "Burner"
import "FungibleToken"
import "NonFungibleToken"

import "EVM"

import "EVMUtils"
import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

access(all) contract FlowEVMBridgeHandlers {

    access(all) let ConfiguratorStoragePath: StoragePath

    access(all) resource CadenceNativeTokenHandler : FlowEVMBridgeHandlerInterfaces.TokenHandler {
        /// Flag determining if request handling is enabled
        access(self) var enabled: Bool
        /// The Cadence Type this handler fulfills requests for
        access(self) var targetType: Type
        /// The EVM contract address this handler fulfills requests for
        access(self) var targetEVMAddress: EVM.EVMAddress?
        /// The Minter enabling minting of Cadence tokens on fulfillment from EVM
        access(self) var minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}

        init(targetType: Type, targetEVMAddress: EVM.EVMAddress?, minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}) {
            self.enabled = false
            self.targetType = targetType
            self.targetEVMAddress = targetEVMAddress
            self.minter <- minter
        }

        /* --- HandlerInfo --- */

        access(all) view fun isEnabled(): Bool {
            return self.enabled
        }
        access(all) view fun getTargetType(): Type? {
            return self.targetType
        }
        access(all) view fun getTargetEVMAddress(): EVM.EVMAddress? {
            return self.targetEVMAddress
        }

        /* --- FTHandler --- */

        access(account)
        fun fulfillTokensToEVM(
            tokens: @{FungibleToken.Vault},
            to: EVM.EVMAddress
        ) {
            // Get values from vault and burn
            let amount = tokens.balance
            let uintAmount = FlowEVMBridgeUtils.ufix64ToUInt256(
                    value: amount,
                    decimals: FlowEVMBridgeConfig.defaultDecimals
                )

            Burner.burn(<-tokens)

            let toPreBalance = FlowEVMBridgeUtils.balanceOf(owner: to, evmContractAddress: self.targetEVMAddress!)
            let bridgePreBalance = FlowEVMBridgeUtils.balanceOf(
                    owner: FlowEVMBridgeUtils.getBridgeCOAEVMAddress(),
                    evmContractAddress: self.targetEVMAddress!
                )

            // Call the EVM contract to transfer escrowed tokens
            let callResult: EVM.Result = FlowEVMBridgeUtils.call(
                    signature: "transfer(address,uint256)",
                    targetEVMAddress: self.getTargetEVMAddress()!,
                    args: [to, uintAmount],
                    gasLimit: 15000000,
                    value: 0.0
                )
            assert(callResult.status == EVM.Status.successful, message: "Tranfer to bridge recipient failed")

            let toPostBalance = FlowEVMBridgeUtils.balanceOf(owner: to, evmContractAddress: self.targetEVMAddress!)
            let bridgePostBalance = FlowEVMBridgeUtils.balanceOf(
                    owner: FlowEVMBridgeUtils.getBridgeCOAEVMAddress(),
                    evmContractAddress: self.targetEVMAddress!
                )

            assert(toPostBalance == toPreBalance + uintAmount, message: "Transfer to bridge recipient failed")
            assert(bridgePostBalance == bridgePreBalance - uintAmount, message: "Transfer to bridge escrow failed")
        }

        access(account)
        fun fulfillTokensFromEVM(
            owner: EVM.EVMAddress,
            type: Type,
            amount: UInt256,
            protectedTransferCall: fun (): EVM.Result
        ): @{FungibleToken.Vault} {
            let ufixAmount = FlowEVMBridgeUtils.uint256ToUFix64(value: amount, decimals: FlowEVMBridgeConfig.defaultDecimals)

            let ownerPreBalance = FlowEVMBridgeUtils.balanceOf(owner: owner, evmContractAddress: self.targetEVMAddress!)
            let bridgePreBalance = FlowEVMBridgeUtils.balanceOf(
                    owner: FlowEVMBridgeUtils.getBridgeCOAEVMAddress(),
                    evmContractAddress: self.targetEVMAddress!
                )

            let transferResult = protectedTransferCall()
            assert(transferResult.status == EVM.Status.successful, message: "Transfer via callback failed")

            let ownerPostBalance = FlowEVMBridgeUtils.balanceOf(owner: owner, evmContractAddress: self.targetEVMAddress!)
            let bridgePostBalance = FlowEVMBridgeUtils.balanceOf(
                    owner: FlowEVMBridgeUtils.getBridgeCOAEVMAddress(),
                    evmContractAddress: self.targetEVMAddress!
                )
            
            assert(ownerPostBalance == ownerPreBalance - amount, message: "Transfer to owner failed")
            assert(bridgePostBalance == bridgePreBalance + amount, message: "Transfer to bridge escrow failed")

            let minted <- self.borrowMinter().mint(amount: ufixAmount)
            return <-minted
        }

        /* --- Admin --- */

        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setTargetType(_ type: Type) {
            self.targetType = type
        }
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setTargetEVMAddress(_ address: EVM.EVMAddress) {
            self.targetEVMAddress = address
        }
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun enableBridging() {
            pre {
                self.minter != nil: "Cannot enable bridging without a TokenMinter resource"
            }
            self.enabled = true
        }

        /* --- Internal --- */

        access(self)
        view fun borrowMinter(): auth(FlowEVMBridgeHandlerInterfaces.Mint) &{FlowEVMBridgeHandlerInterfaces.TokenMinter} {
            return &self.minter
        }
    }

    access(all) resource HandlerConfigurator {
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun createTokenHandler(
            handlerType: Type,
            targetType: Type,
            targetEVMAddress: EVM.EVMAddress?,
            minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}
        ) {
            switch handlerType {
                case Type<@CadenceNativeTokenHandler>():
                    // TODO: emit creation event
                    let handler <-create CadenceNativeTokenHandler(
                        targetType: targetType,
                        targetEVMAddress: targetEVMAddress,
                        minter: <-minter
                    )
                    FlowEVMBridgeConfig.addHandler(<-handler)
                default:
                    panic("Invalid Handler type requested")
            }
        }
    }

    init() {
        self.ConfiguratorStoragePath = /storage/BridgeHandlerConfigurator
        self.account.storage.save(<-create HandlerConfigurator(), to: self.ConfiguratorStoragePath)
    }
}
