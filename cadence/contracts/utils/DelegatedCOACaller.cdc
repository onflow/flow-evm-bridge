import "FungibleToken"

import "EVM"

import "FlowEVMBridgeUtils"

access(all)
contract DelegatedCOACaller {

    access(all)
    let pathPrefix: String

    access(all)
    event CallerCreated(address: EVM.EVMAddress, owner: Address?)
    
    access(all)
    struct interface ICallParameters {
        access(all) let to: EVM.EVMAddress
        access(all) let data: [UInt8]
        access(all) let gasLimit: UInt64
        access(all) let value: EVM.Balance
    }

    access(all)
    struct CallParameters : ICallParameters{
        access(all) let to: EVM.EVMAddress
        access(all) let data: [UInt8]
        access(all) let gasLimit: UInt64
        access(all) let value: EVM.Balance

        init(
            to: EVM.EVMAddress,
            data: [UInt8],
            gasLimit: UInt64,
            value: EVM.Balance
        ) {
            self.to = to
            self.data = data
            self.gasLimit = gasLimit
            self.value = value
        }
    }

    access(all)
    resource interface ICaller : EVM.Addressable {
        access(all)
        var pendingCall: {ICallParameters}?

        access(EVM.Owner | EVM.Call)
        fun setPendingCall(_ parameters: {ICallParameters}) {
            pre {
                self.pendingCall == nil: "Call already pending"
            }
        }

        access(EVM.Owner | EVM.Call)
        fun reset() {
            self.pendingCall = nil
        }

        access(all)
        fun executeCall(): EVM.Result {
            pre {
                self.pendingCall != nil: "No pending call found"
            }
            post {
                self.pendingCall == nil
            }
        }
    }

    access(all)
    resource Caller : ICaller, EVM.Addressable {
        access(self) 
        let coaCapability: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>
        access(all)
        var pendingCall: {ICallParameters}?

        init(coaCapability: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>) {
            pre {
                coaCapability.borrow() != nil: "Invalid COA Capability"
            }
            self.coaCapability = coaCapability
            self.pendingCall = nil
        }

        /// The EVM address of the associated CadenceOwnedAccount
        access(all)caSt
        view fun address(): EVM.EVMAddress {
            return self.borrowCOA().address()
        }

        access(all)
        fun executeCall(): EVM.Result {
            let callResult = self.borrowCOA().call(
                to: self.pendingCall!.to,
                data: self.pendingCall!.data,
                gasLimit: self.pendingCall!.gasLimit,
                value: self.pendingCall!.value
            )
            self.reset()
            return callResult
        }

        access(EVM.Owner | EVM.Call)
        fun setPendingCall(_ parameters: {ICallParameters}) {
            self.pendingCall = parameters
        }

        access(EVM.Owner | EVM.Call)
        fun reset() {
            self.pendingCall = nil
        }

        access(self)
        view fun borrowCOA(): auth(EVM.Call) &EVM.CadenceOwnedAccount {
            return self.coaCapability.borrow() ?? panic("Invalid COA Capability")
        }
    }

    access(all)
    fun createCaller(coaCapability: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>): @Caller {
        let caller <- create Caller(coaCapability: coaCapability)
        emit CallerCreated(address: caller.address(), owner: coaCapability.borrow()!.owner?.address)
        return <-caller
    }

    access(all)
    view fun deriveStoragePath(from coaAddress: EVM.EVMAddress): StoragePath? {
        let addressHex = FlowEVMBridgeUtils.getEVMAddressAsHexString(address: coaAddress)
        return StoragePath(identifier: self.pathPrefix.concat(addressHex))
    }

    init() {
        self.pathPrefix = "delegatedCOACaller_"
    }
}
