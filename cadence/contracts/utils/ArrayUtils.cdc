// Copied from https://github.com/green-goo-dao/flow-utils/blob/crescendo/contracts/ArrayUtils.cdc
// Special thanks to the Green Goo Dao contributors for creating this contract
access(all) contract ArrayUtils {
    access(all) fun rangeFunc(_ start: Int, _ end: Int, _ f: fun (Int): Void) {
        var current = start
        while current < end {
            f(current)
            current = current + 1
        }
    }

    access(all) fun range(_ start: Int, _ end: Int): [Int] {
        var res: [Int] = []
        self.rangeFunc(start, end, fun (i: Int) {
            res.append(i)
        })
        return res
    }
}
