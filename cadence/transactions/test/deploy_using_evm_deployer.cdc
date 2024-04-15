import "EVMDeployer"

transaction(name: String, bytecode: String, value: UInt) {
    prepare(signer: &Account) {}

    execute {
        EVMDeployer.deploy(name: name, bytecode: bytecode, value: value)
    }
}
