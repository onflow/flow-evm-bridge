import "FlowToken"

access(all) contract EVM {

    access(self) let balances: {String: Balance}
    access(self) let bridgePool: @FlowToken.Vault

    access(all) let StoragePath: StoragePath
    access(all) let PublicPath: PublicPath

    access(all) event BridgedAccountCreated(address: String)
    access(all) event TokensBridged(to: String?, from: String?, amount: UFix64)


    /// EVMAddress is an EVM-compatible address
    access(all) struct EVMAddress {

        /// Bytes of the address
        access(all) let bytes: [UInt8; 20]

        /// Constructs a new EVM address from the given byte representation
        init(bytes: [UInt8; 20]) {
            self.bytes = bytes
        }

        /// Returns the balance of this address
        access(all) fun balance(): Balance {
            return EVM.balances[self.toString()] ?? Balance(flow: 0.0)
        }

        access(all) fun toString(): String {
            let b: [UInt8] = []
            for byte in self.bytes {
                b.append(byte)
            }
            return String.encodeHex(b)
        }
    }

    access(all) struct Balance {
        /// The balance in FLOW
        access(all) let flow: UFix64

        /// Constructs a new balance, given the balance in FLOW
        init(flow: UFix64) {
            self.flow = flow
        }

        /// Returns the balance in terms of atto-FLOW.
        /// Atto-FLOW is the smallest denomination of FLOW inside EVM
        // access(all) fun toAttoFlow(): UInt64
    }

    access(all) resource interface BridgedAccountPublic {
        access(all) fun address(): EVMAddress
    }

    access(all) resource BridgedAccount : BridgedAccountPublic {

        access(self)
        let addressBytes: [UInt8; 20]

        /// constructs a new bridged account for the address
        init(addressBytes: [UInt8; 20]) {
            self.addressBytes = addressBytes
        }

        /// The EVM address of the bridged account
        access(all)
        fun address(): EVMAddress {
            return EVMAddress(bytes: self.addressBytes)
        }

        /// Deposits the given vault into the EVM account with the given address
        access(all) fun deposit(from: @FlowToken.Vault) {
            let fromBalance = from.balance
            let currentBalance = EVM.balances.remove(key: self.address().toString())

            if currentBalance == nil {
                EVM.balances.insert(
                    key: self.address().toString(),
                    Balance(flow: fromBalance)
                )
            } else {
                EVM.balances.insert(
                    key: self.address().toString(),
                    Balance(flow: currentBalance!.flow + fromBalance)
                )
            }

            emit TokensBridged(to: self.address().toString(), from: nil, amount: fromBalance)

            EVM.bridgePool.deposit(from: <-from)
        }

        /// Withdraws the balance from the bridged account's balance
        access(all)
        fun withdraw(balance: Balance): @FlowToken.Vault {

            let currentBalance = EVM.balances.remove(key: self.address().toString())
                ?? panic("No Balance found for this BridgedAccount address")
            EVM.balances.insert(
                key: self.address().toString(),
                Balance(
                    flow: currentBalance.flow - balance.flow
                )
            )

            emit TokensBridged(to: nil, from: self.address().toString(), amount: balance.flow)

            let vault: @FlowToken.Vault <- EVM.bridgePool.withdraw(amount: balance.flow) as! @FlowToken.Vault
            return <- vault
        }

        /// Deploys a contract to the EVM environment.
        /// Returns the address of the newly deployed contract
        access(all)
        fun deploy(code: [UInt8], gasLimit: UInt64, value: Balance): EVMAddress {
            // MOCK: return random address
            return EVMAddress(bytes: EVM.getRandomAddressBytes())
        }

        /// Calls a function with the given data.
        /// The execution is limited by the given amount of gas
        access(all)
        fun call(to: EVMAddress, data: [UInt8], gasLimit: UInt64, value: Balance): [UInt8] {
            // MOCK: return random bytes
            return revertibleRandom().toBigEndianBytes()
        }
    }

    /// Creates a new bridged account
    access(all)
    fun createBridgedAccount(): @BridgedAccount {
        // MOCK: Address creation
        let addressBytes: [UInt8; 20] = self.getRandomAddressBytes()
        // let addressBytes = InternalEVM.createBridgedAccount()

        let bridgedAccount <-create BridgedAccount(
            // addressBytes: addressBytes
            addressBytes: addressBytes
        )
        self.balances.insert(key: bridgedAccount.address().toString(), Balance(flow: 0.0))

        emit BridgedAccountCreated(address: bridgedAccount.address().toString())

        return <- bridgedAccount
    }

    access(all) fun getBalance(address: String): Balance? {
        return EVM.balances[address]
    }

    access(all) fun getBridePoolBalance(): UFix64 {
        return self.bridgePool.balance
    }

    // MOCK
    access(all) fun getRandomAddressBytes(): [UInt8; 20] {
        let arr = revertibleRandom().toBigEndianBytes()
        arr.appendAll(
            revertibleRandom().toBigEndianBytes()
        )
        arr.appendAll(
            revertibleRandom().toBigEndianBytes().slice(from: 0, upTo: 4)
        )
        let addressBytes: [UInt8; 20] = [
                arr[0], arr[1], arr[2], arr[3], arr[4],
                arr[5], arr[6], arr[7], arr[8], arr[9],
                arr[10], arr[11], arr[12], arr[13], arr[14],
                arr[15], arr[16], arr[17], arr[18], arr[19]
            ]
        return addressBytes
    }

    init() {
        self.balances = {}
        self.bridgePool <- FlowToken.createEmptyVault() as! @FlowToken.Vault

        self.StoragePath = /storage/EVMBridgedAccount
        self.PublicPath = /public/EVMBridgedAccount
    }
}
