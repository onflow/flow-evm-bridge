import "Burner"
import "FungibleToken"
import "NonFungibleToken"
import "FlowToken"

import "EVM"

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
        /// The expected minter type for minting tokens on fulfillment
        access(self) let expectedMinterType: Type
        /// The Minter enabling minting of Cadence tokens on fulfillment from EVM
        access(self) var minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}?

        init(targetType: Type, targetEVMAddress: EVM.EVMAddress?, expectedMinterType: Type) {
            pre {
                expectedMinterType.isSubtype(of: Type<@{FlowEVMBridgeHandlerInterfaces.TokenMinter}>()):
                    "Invalid minter type"
            }
            self.enabled = false
            self.targetType = targetType
            self.targetEVMAddress = targetEVMAddress
            self.expectedMinterType = expectedMinterType
            self.minter <- nil
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

        /// Returns the expected minter type for the handler
        access(all) view fun getExpectedMinterType(): Type? {
            return self.expectedMinterType
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
            let evmAddress = self.getTargetEVMAddress()!

            // Get values from vault and burn
            let amount = tokens.balance
            let uintAmount = FlowEVMBridgeUtils.convertCadenceAmountToERC20Amount(amount, erc20Address: evmAddress)

            assert(uintAmount > UInt256(0), message: "Amount to bridge must be greater than 0")

            Burner.burn(<-tokens)

            FlowEVMBridgeUtils.mustTransferERC20(to: to, amount: uintAmount, erc20Address: evmAddress)
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
            let evmAddress = self.getTargetEVMAddress()!

            // Convert the amount to a UFix64
            let ufixAmount = FlowEVMBridgeUtils.convertERC20AmountToCadenceAmount(
                    amount,
                    erc20Address: evmAddress
                )
            assert(ufixAmount > 0.0, message: "Amount to bridge must be greater than 0")

            FlowEVMBridgeUtils.mustEscrowERC20(
                owner: owner,
                amount: amount,
                erc20Address: evmAddress,
                protectedTransferCall: protectedTransferCall
            )

            // After state confirmation, mint the tokens and return
            let minter = self.borrowMinter() ?? panic("Minter not set")
            let minted <- minter.mint(amount: ufixAmount)
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

        /// Sets the target type for the handler
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setMinter(_ minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}) {
            pre {
                self.minter == nil: "Minter has already been set"
            }
            self.minter <-! minter
        }

        /// Enables the handler for request handling. The
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun enableBridging() {
            pre {
                self.minter != nil: "Cannot enable handler without a minter"
            }
            self.enabled = true
        }

        /* --- Internal --- */

        /// Returns an entitled reference to the encapsulated minter resource
        access(self)
        view fun borrowMinter(): auth(FlowEVMBridgeHandlerInterfaces.Mint) &{FlowEVMBridgeHandlerInterfaces.TokenMinter}? {
            return &self.minter
        }
    }

    /// Facilitates moving Flow between Cadence and EVM as WFLOW. Since WFLOW is an artifact of the EVM ecosystem, 
    /// wrapping the native token as an ERC20, it does not have a place in Cadence's fungible token ecosystem.
    /// Given the native interface on EVM.CadenceOwnedAccount and EVM.EVMAddress to move FLOW between Cadence and EVM,
    /// this handler treats requests to bridge FLOW as WFLOW as a special case.
    ///
    access(all) resource WFLOWTokenHandler : FlowEVMBridgeHandlerInterfaces.TokenHandler {
        /// Flag determining if request handling is enabled
        access(self) var enabled: Bool
        /// The Cadence Type this handler fulfills requests for. This field is optional in the event the Cadence token
        /// contract address is not yet known but the EVM Address must still be filtered via Handler to prevent the
        /// contract from being onboarded otherwise.
        access(self) var targetType: Type
        /// The EVM contract address this handler fulfills requests for.
        access(self) var targetEVMAddress: EVM.EVMAddress

        init(wflowEVMAddress: EVM.EVMAddress) {
            self.enabled = false
            self.targetType = Type<@FlowToken.Vault>()
            self.targetEVMAddress = wflowEVMAddress
        }

        /// Returns whether the Handler is enabled
        access(all) view fun isEnabled(): Bool {
            return self.enabled
        }
        /// Returns the Cadence type handled by the Handler, nil if not set
        access(all) view fun getTargetType(): Type? {
            return self.targetType
        }
        /// Returns the EVM address handled by the Handler, nil if not set
        access(all) view fun getTargetEVMAddress(): EVM.EVMAddress? {
            return self.targetEVMAddress
        }
        /// Returns nil as this handler simply unwraps WFLOW to FLOW
        access(all) view fun getExpectedMinterType(): Type? {
            return nil
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
            pre {
                tokens.getType() == Type<@FlowToken.Vault>():
                "Invalid token type=".concat(tokens.getType().identifier)
                    .concat(" - WFLOWTokenHandler only handles FlowToken Vault")
            }
            let flowVault <- tokens as! @FlowToken.Vault
            let wflowAddress = self.getTargetEVMAddress()!

            // Get balance from vault
            let balance = flowVault.balance
            let uintAmount = FlowEVMBridgeUtils.convertCadenceAmountToERC20Amount(balance, erc20Address: wflowAddress)

            // Deposit to bridge COA
            let coa = FlowEVMBridgeUtils.borrowCOA()
            coa.deposit(from: <-flowVault)

            let preBalance = FlowEVMBridgeUtils.balanceOf(owner: coa.address(), evmContractAddress: wflowAddress)

            // Wrap the deposited FLOW as WFLOW, giving the bridge COA the necessary WFLOW to transfer
            let wrapResult = FlowEVMBridgeUtils.call(
                signature: "deposit()",
                targetEVMAddress: wflowAddress,
                args: [],
                gasLimit: FlowEVMBridgeConfig.gasLimit,
                value: balance
            )
            assert(wrapResult.status == EVM.Status.successful, message: "Failed to wrap FLOW as WFLOW")
            
            let postBalance = FlowEVMBridgeUtils.balanceOf(owner: coa.address(), evmContractAddress: wflowAddress)

            // Cover underflow
            assert(
                postBalance > preBalance,
                message: "Balance decremented after wrapping FLOW"
            )
            // Confirm bridge COA's WFLOW balance has incremented by the expected amount
            assert(
                postBalance - preBalance == uintAmount,
                message: "Balance after wrapping FLOW does not match requested amount - expected="
                    .concat((preBalance + uintAmount).toString())
                    .concat(" actual=")
                    .concat((postBalance - preBalance).toString())
            )

            // Transfer WFLOW to recipient
            FlowEVMBridgeUtils.mustTransferERC20(to: to, amount: uintAmount, erc20Address: wflowAddress)
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
            let wflowAddress = self.getTargetEVMAddress()!

            // Convert the amount to a UFix64
            let ufixAmount = FlowEVMBridgeUtils.convertERC20AmountToCadenceAmount(
                    amount,
                    erc20Address: wflowAddress
                )
            assert(ufixAmount > 0.0, message: "Amount to bridge must be greater than 0")

            // Transfers WFLOW to bridge COA as escrow
            FlowEVMBridgeUtils.mustEscrowERC20(
                owner: owner,
                amount: amount,
                erc20Address: wflowAddress,
                protectedTransferCall: protectedTransferCall
            )

            // Get the bridge COA's FLOW balance before unwrapping WFLOW
            let coa = FlowEVMBridgeUtils.borrowCOA()
            let preBalance = coa.balance().attoflow

            // Unwrap the transferred WFLOW to FLOW, giving the bridge COA the necessary FLOW to withdraw from EVM
            let unwrapResult = FlowEVMBridgeUtils.call(
                signature: "withdraw(uint)",
                targetEVMAddress: wflowAddress,
                args: [UInt(amount)],
                gasLimit: FlowEVMBridgeConfig.gasLimit,
                value: 0.0
            )
            assert(unwrapResult.status == EVM.Status.successful, message: "Failed to unwrap WFLOW as FLOW")

            let postBalance = coa.balance().attoflow

            // Cover underflow
            assert(
                postBalance > preBalance,
                message: "Balance decremented after unwrapping WFLOW"
            )
            // Confirm bridge COA's FLOW balance has incremented by the expected amount
            assert(
                UInt256(postBalance - preBalance) == amount,
                message: "Balance after unwrapping WFLOW does not match requested amount - expected="
                    .concat((UInt256(preBalance) + amount).toString())
                    .concat(" actual=")
                    .concat((postBalance - preBalance).toString())
            )

            // Withdraw FLOW from bridge COA
            let withdrawBalance = EVM.Balance(attoflow: UInt(amount))
            assert(
                UInt256(withdrawBalance.attoflow) == amount,
                message: "Balance failed to convert to attoflow - expected="
                    .concat(amount.toString())
                    .concat(" actual=")
                    .concat(withdrawBalance.attoflow.toString())
            )
            let flowVault <- coa.withdraw(balance: withdrawBalance)
            assert(
                flowVault.balance == ufixAmount,
                message: "Vault balance does not match requested amount - expected="
                    .concat(ufixAmount.toString())
                    .concat(" actual=")
                    .concat(flowVault.balance.toString())
            )
            return <-flowVault
        }

        /* --- Admin --- */

        /// Sets the target type for the handler
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setTargetType(_ type: Type) {
            panic("WFLOWTokenHandler has targetType set at initialization")
        }

        /// Sets the target EVM address for the handler
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setTargetEVMAddress(_ address: EVM.EVMAddress) {
            panic("WFLOWTokenHandler has EVMAddress set at initialization")
        }

        /// Sets the target type for the handler
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setMinter(_ minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}) {
            panic("WFLOWTokenHandler does not utilize a minter")
        }

        /// Enables the handler for request handling. The
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun enableBridging() {
            self.enabled = true
        }

        /* --- Internal --- */

        /// Returns an entitled reference to the encapsulated minter resource
        access(self)
        view fun borrowMinter(): auth(FlowEVMBridgeHandlerInterfaces.Mint) &{FlowEVMBridgeHandlerInterfaces.TokenMinter}? {
            return nil
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
        /// @param expectedMinterType: The Type of the expected minter to be set for the created TokenHandler
        ///
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun createTokenHandler(
            handlerType: Type,
            targetType: Type,
            targetEVMAddress: EVM.EVMAddress?,
            expectedMinterType: Type?
        ) {
            switch handlerType {
                case Type<@CadenceNativeTokenHandler>():
                    assert(
                        expectedMinterType != nil,
                        message: "CadenceNativeTokenHandler requires an expected minter type but received nil"
                    )
                    let handler <-create CadenceNativeTokenHandler(
                        targetType: targetType,
                        targetEVMAddress: targetEVMAddress,
                        expectedMinterType: expectedMinterType!
                    )
                    FlowEVMBridgeConfig.addTokenHandler(<-handler)
                case Type<@WFLOWTokenHandler>():
                    assert(
                        targetEVMAddress != nil,
                        message: "WFLOWTokenHandler requires a target EVM address but received nil"
                    )
                    let handler <-create WFLOWTokenHandler(wflowEVMAddress: targetEVMAddress!)
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
