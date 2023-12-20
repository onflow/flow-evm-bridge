import "StorageBenchmark"

transaction(strings: [String]) {
    prepare(signer: AuthAccount) {
        StorageBenchmark.store(strings: strings)
    }
}
