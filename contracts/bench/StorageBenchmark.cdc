access(all) contract StorageBenchmark {
    access(all) let storage: @{UInt64: R}

    access(all) resource R {
        access(all) let s: String
        
        init(_ s: String) {
            self.s = s
        }
    }

    access(all) fun createR(s: String): @R {
        return <-create R(s)
    }

    access(all) fun store(strings: [String]) {
        for s in strings {
            let r <- self.createR(s: s)
            self.storage[r.uuid] <-! r
        }
    }

    init() {
        self.storage <- {}
    }
}