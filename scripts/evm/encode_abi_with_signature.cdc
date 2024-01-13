import "EVM"

// access(all) fun main(signature: String, args: [AnyStruct]): String {
access(all) fun main(signature: String): String {

    let methodID = HashAlgorithm.KECCAK_256.hash(
            signature.utf8
        ).slice(from: 0, upTo: 4)
    return String.encodeHex(methodID.concat(EVM.encodeABI(args)))

    // let methodID = HashAlgorithm.KECCAK_256.hash(
    //         "deployERC721(string,string,string,string)".utf8
    //     ).slice(from: 0, upTo: 4)
    // let args = ["name","symbol","address","identifier"]
    // return String.encodeHex(methodID.concat(EVM.encodeABI(args)))
}
