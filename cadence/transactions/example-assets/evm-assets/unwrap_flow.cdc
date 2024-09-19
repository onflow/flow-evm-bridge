import "FungibleToken"
import "FlowToken"

import "EVM"

import "FlowEVMBridgeUtils"

/// This transactions wraps FLOW tokens as WFLOW tokens, using the signing COA's EVM FLOW balance primarily. If the 
/// EVM balance is insufficient, the transaction will transfer FLOW from the Cadence balance to the EVM balance.
///
/// @param wflowContractHex: The EVM address of the WFLOW contract as a hex string
/// @param amount: The amount of FLOW to wrap as WFLOW
///
transaction(wflowContractHex: String, amount: UInt256) {

    let wflowAddress: EVM.EVMAddress
    let preBalance: UInt
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    var postBalance: UInt

    prepare(signer: auth(BorrowValue) &Account) {
        self.wflowAddress = EVM.addressFromString(wflowContractHex)
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA from provided gateway address")
        self.preBalance = UInt(FlowEVMBridgeUtils.balanceOf(owner: self.coa.address(), evmContractAddress: self.wflowAddress))
        self.postBalance = 0
    }

    execute {
        // Encode the withdraw function call
        let calldata = EVM.encodeABIWithSignature("withdraw(uint)", [UInt(amount)])
        // Define the value to send to the WFLOW contract - 0 to unwrap
        let value = EVM.Balance(attoflow: 0)
        // Call the WFLOW contract which should complete the unwrap
        let result = self.coa.call(
            to: self.wflowAddress,
            data: calldata,
            gasLimit: 15_000_000,
            value: value
        )
        assert(result.status == EVM.Status.successful, message: "Failed to wrap FLOW as WFLOW")
        self.postBalance = UInt(FlowEVMBridgeUtils.balanceOf(owner: self.coa.address(), evmContractAddress: self.wflowAddress))
    }

    post {
        self.postBalance == self.preBalance - UInt(amount):
        "Incorrect post balance - expected=".concat((self.preBalance - UInt(amount)).toString())
        .concat(" | actual=").concat(self.postBalance.toString())
    }
}
