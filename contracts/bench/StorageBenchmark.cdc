access(all) contract StorageBenchmark {
    access(all) let storage: @{UInt64: R}
    access(self) var firstID: UInt64?

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
            if self.firstID == nil {
                self.firstID = r.uuid
            }
            self.storage[r.uuid] <-! r
        }
    }

    access(all) fun getFirstString(): String {
        return self.storage[self.firstID!]?.s!
    }

    init() {
        self.storage <- {}
        self.firstID = nil
    }
}