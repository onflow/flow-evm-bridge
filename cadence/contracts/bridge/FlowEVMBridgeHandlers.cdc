import "Burner"
import "FungibleToken"
import "NonFungibleToken"

import "EVM"

import "EVMUtils"
import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeUtils"

/// FlowEVMBridgeHandlers
///
/// This contract is responsible for defining and configuring bridge handlers for special cased assets.
///
access(all) contract FlowEVMBridgeHandlers {

    /**********************
        Contract Fields
    ***********************/

    /// The storage path for the HandlerConfigurator resource
    access(all) let ConfiguratorStoragePath: StoragePath

    /****************
        Constructs
    *****************/

    /// Handler for bridging Cadence native fungible tokens to EVM. In the event a Cadence project migrates native
    /// support to EVM, this Hander can be configured to facilitate bridging the Cadence tokens to EVM. This Handler
    /// then effectively allows the bridge to treat such tokens as bridge-defined on the Cadence side and EVM-native on
    /// the EVM side minting/burning in Cadence and escrowing in EVM.
    /// In order for this to occur, neither the Cadence token nor the EVM contract can be onboarded to the bridge - in
    /// essence, neither side of the asset can be onboarded to the bridge.
    /// The Handler must be configured in the bridge via the HandlerConfigurator. Once added, the bridge will filter
    /// requests to bridge the token Vault to EVM through this Handler which cannot be enabled until a target EVM 
    /// address is set. Once the corresponding EVM contract address is known, it can be set and the Handler. It's also
    /// suggested that the Handler only be enabled once sufficient liquidity has been arranged in bridge escrow on the
    /// EVM side.
    ///
    access(all) resource CadenceNativeTokenHandler : FlowEVMBridgeHandlerInterfaces.TokenHandler {
        /// Flag determining if request handling is enabled
        access(self) var enabled: Bool
        /// The Cadence Type this handler fulfills requests for
        access(self) var targetType: Type
        /// The EVM contract address this handler fulfills requests for. This field is optional in the event the EVM
        /// contract address is not yet known but the Cadence type must still be filtered via Handler to prevent the
        /// type from being onboarded otherwise.
        access(self) var targetEVMAddress: EVM.EVMAddress?
        /// The Minter enabling minting of Cadence tokens on fulfillment from EVM
        access(self) let minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}

        init(targetType: Type, targetEVMAddress: EVM.EVMAddress?, minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}) {
            self.enabled = false
            self.targetType = targetType
            self.targetEVMAddress = targetEVMAddress
            self.minter <- minter
        }

        /* --- HandlerInfo --- */

        /// Returns the enabled status of the handler
        access(all) view fun isEnabled(): Bool {
            return self.enabled
        }

        /// Returns the type of the asset the handler is configured to handle
        access(all) view fun getTargetType(): Type? {
            return self.targetType
        }

        /// Returns the EVM contract address the handler is configured to handle
        access(all) view fun getTargetEVMAddress(): EVM.EVMAddress? {
            return self.targetEVMAddress
        }

        /* --- TokenHandler --- */

        /// Fulfill a request to bridge tokens from Cadence to EVM, burning the provided Vault and transferring from
        /// EVM escrow to the named recipient. Assumes any fees are handled by the caller within the bridge contracts
        ///
        /// @param tokens: The Vault containing the tokens to bridge
        /// @param to: The EVM address to transfer the tokens to
        ///
        access(account)
        fun fulfillTokensToEVM(
            tokens: @{FungibleToken.Vault},
            to: EVM.EVMAddress
        ) {
            // Get values from vault and burn
            let amount = tokens.balance
            let uintAmount = FlowEVMBridgeUtils.ufix64ToUInt256(
                    value: amount,
                    decimals: FlowEVMBridgeUtils.getTokenDecimals(evmContractAddress: self.getTargetEVMAddress()!)
                )

            Burner.burn(<-tokens)

            // Get the recipient and escrow balances before transferring 
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

            // Get the resulting balances after transfer
            let toPostBalance = FlowEVMBridgeUtils.balanceOf(owner: to, evmContractAddress: self.targetEVMAddress!)
            let bridgePostBalance = FlowEVMBridgeUtils.balanceOf(
                    owner: FlowEVMBridgeUtils.getBridgeCOAEVMAddress(),
                    evmContractAddress: self.targetEVMAddress!
                )

            // Recipient should have received the tokens and bridge escrow should have decreased
            assert(toPostBalance == toPreBalance + uintAmount, message: "Transfer to bridge recipient failed")
            assert(bridgePostBalance == bridgePreBalance - uintAmount, message: "Transfer to bridge escrow failed")
        }

        /// Fulfill a request to bridge tokens from EVM to Cadence, minting the provided amount of tokens in Cadence
        /// and transferring from the named owner to bridge escrow in EVM.
        ///
        /// @param owner: The EVM address of the owner of the tokens. Should also be the caller executing the protected
        ///              transfer call.
        /// @param type: The type of the asset being bridged
        /// @param amount: The amount of tokens to bridge
        ///
        /// @return The minted Vault containing the the requested amount of Cadence tokens
        ///
        access(account)
        fun fulfillTokensFromEVM(
            owner: EVM.EVMAddress,
            type: Type,
            amount: UInt256,
            protectedTransferCall: fun (): EVM.Result
        ): @{FungibleToken.Vault} {
            // Convert the amount to a UFix64
            let ufixAmount = FlowEVMBridgeUtils.uint256ToUFix64(
                    value: amount,
                    decimals: FlowEVMBridgeUtils.getTokenDecimals(evmContractAddress: self.getTargetEVMAddress()!)
                )

            // Get the owner and escrow balances before transfer
            let ownerPreBalance = FlowEVMBridgeUtils.balanceOf(owner: owner, evmContractAddress: self.targetEVMAddress!)
            let bridgePreBalance = FlowEVMBridgeUtils.balanceOf(
                    owner: FlowEVMBridgeUtils.getBridgeCOAEVMAddress(),
                    evmContractAddress: self.targetEVMAddress!
                )

            // Call the protected transfer function which should execute a transfer call from the owner to escrow
            let transferResult = protectedTransferCall()
            assert(transferResult.status == EVM.Status.successful, message: "Transfer via callback failed")

            // Get the resulting balances after transfer
            let ownerPostBalance = FlowEVMBridgeUtils.balanceOf(owner: owner, evmContractAddress: self.targetEVMAddress!)
            let bridgePostBalance = FlowEVMBridgeUtils.balanceOf(
                    owner: FlowEVMBridgeUtils.getBridgeCOAEVMAddress(),
                    evmContractAddress: self.targetEVMAddress!
                )
            
            // Confirm the transfer of the expected was successful in both sending owner and recipient escrow
            assert(ownerPostBalance == ownerPreBalance - amount, message: "Transfer to owner failed")
            assert(bridgePostBalance == bridgePreBalance + amount, message: "Transfer to bridge escrow failed")

            // After state confirmation, mint the tokens and return
            let minted <- self.borrowMinter().mint(amount: ufixAmount)
            return <-minted
        }

        /* --- Admin --- */

        /// Sets the target type for the handler
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setTargetType(_ type: Type) {
            self.targetType = type
        }

        /// Sets the target EVM address for the handler 
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setTargetEVMAddress(_ address: EVM.EVMAddress) {
            self.targetEVMAddress = address
        }

        /// Enables the handler for request handling. The 
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun enableBridging() {
            self.enabled = true
        }

        /* --- Internal --- */

        /// Returns an entitled reference to the encapsulated minter resource
        access(self)
        view fun borrowMinter(): auth(FlowEVMBridgeHandlerInterfaces.Mint) &{FlowEVMBridgeHandlerInterfaces.TokenMinter} {
            return &self.minter
        }
    }

    /// This resource enables the configuration of Handlers. These Handlers are stored in FlowEVMBridgeConfig from which
    /// further setting and getting can be executed.
    ///
    access(all) resource HandlerConfigurator {
        /// Creates a new Handler and adds it to the bridge configuration
        ///
        /// @param handlerType: The type of handler to create as defined in this contract
        /// @param targetType: The type of the asset the handler will handle.
        /// @param targetEVMAddress: The EVM contract address the handler will handle, can be nil if still unknown
        /// @param minter: The minter resource to use for minting tokens on fulfillment
        ///
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun createTokenHandler(
            handlerType: Type,
            targetType: Type,
            targetEVMAddress: EVM.EVMAddress?,
            minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}
        ) {
            switch handlerType {
                case Type<@CadenceNativeTokenHandler>():
                    let handler <-create CadenceNativeTokenHandler(
                        targetType: targetType,
                        targetEVMAddress: targetEVMAddress,
                        minter: <-minter
                    )
                    FlowEVMBridgeConfig.addTokenHandler(<-handler)
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
