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

    access(all) fun reverse(_ array: [Int]): [Int] {
        var res: [Int] = []
        var i: Int = array.length - 1
        while i >= 0 {
            res.append(array[i])
            i = i - 1
        }
        return res
    }

    access(all) fun transform(_ array: auth(Mutate) &[AnyStruct], _ f : fun (&AnyStruct)){
        for i in self.range(0, array.length){
            f(array[i])
        }
    }

    access(all) fun iterate(_ array: [AnyStruct], _ f : fun (AnyStruct): Bool) {
        for item in array{
            if !f(item){
                break
            }
        }
    }

    access(all) fun map(_ array: [AnyStruct], _ f : fun (AnyStruct): AnyStruct) : [AnyStruct] {
        var res : [AnyStruct] = []
        for item in array{
            res.append(f(item))
        }
        return res
    }

    access(all) fun mapStrings(_ array: [String], _ f: fun (String) : String) : [String] {
        var res : [String] = []
        for item in array{
            res.append(f(item))
        }
        return res
    }

    access(all) fun reduce(_ array: [AnyStruct], _ initial: AnyStruct, _ f : fun (AnyStruct, AnyStruct): AnyStruct) : AnyStruct{
        var res: AnyStruct = f(initial, array[0])
        for i in self.range(1, array.length){
            res =  f(res, array[i])
        }
        return res
    }

}