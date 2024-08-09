import "EVM"

/// Contract for fetching tokenURIs from EVM ERC721 contracts
///
access(all) contract TokenURIFetcher {

    access(self) let passthroughCOA: @EVM.CadenceOwnedAccount

    /// Retrieves the tokenURI for a given token ID from an EVM ERC721 contract. Reverts on call failure.
    ///
    /// @param evmContractAddress: The EVM address of the ERC721 contract
    /// @param id: The token ID to retrieve the URI for
    ///
    /// @return The tokenURI for the given token ID
    ///
    access(all)
    fun getTokenURI(evmContractAddress: EVM.EVMAddress, id: UInt256): String {
        // Encode calldata
        let calldata = EVM.encodeABIWithSignature(
            "tokenURI(uint256)", // Function signature
            [id] // Function args
        )
        // Execute call
        let callResult = self.passthroughCOA.call(
            to: evmContractAddress,
            data: calldata,
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        // Ensure call was successful
        assert(callResult.status == EVM.Status.successful, message: "Call to EVM for tokenURI failed")
        let decodedResult = EVM.decodeABI(types: [Type<String>()], data: callResult.data)
        assert(decodedResult.length == 1, message: "Invalid response length")

        // Return decoded response
        return decodedResult[0] as! String
    }


    init() {
        self.passthroughCOA <-EVM.createCadenceOwnedAccount()
    }
}