import Crypto

import "EVM"

/// Creates a new Flow Address and EVM account with a Cadence Owned Account (COA) stored in the account's storage.
///
transaction(
    key: String,  // key to be used for the account
    signatureAlgorithm: UInt8, // signature algorithm to be used for the account
    hashAlgorithm: UInt8, // hash algorithm to be used for the account
    weight: UFix64, // weight to be used for the account
) {
    let auth: auth(Storage, Keys, Capabilities) &Account

    prepare(signer: auth(Storage, Keys, Capabilities) &Account) {
        pre {
            signatureAlgorithm >= 1 && signatureAlgorithm <= 3:
                "Cannot add Key: Must provide a signature algorithm raw value that corresponds to "
                .concat("one of the available signature algorithms for Flow keys.")
                .concat("You provided ").concat(signatureAlgorithm.toString())
                .concat(" but the options are either 1 (ECDSA_P256), 2 (ECDSA_secp256k1), or 3 (BLS_BLS12_381).")
            hashAlgorithm >= 1 && hashAlgorithm <= 6:
                "Cannot add Key: Must provide a hash algorithm raw value that corresponds to "
                .concat("one of of the available hash algorithms for Flow keys.")
                .concat("You provided ").concat(hashAlgorithm.toString())
                .concat(" but the options are 1 (SHA2_256), 2 (SHA2_384), 3 (SHA3_256), ")
                .concat("4 (SHA3_384), 5 (KMAC128_BLS_BLS12_381), or 6 (KECCAK_256).")
            weight <= 1000.0:
                "Cannot add Key: The key weight must be between 0 and 1000."
                .concat(" You provided ").concat(weight.toString()).concat(" which is invalid.")
        }

        self.auth = signer
    }

    execute {
        // Create a new public key
        let publicKey = PublicKey(
            publicKey: key.decodeHex(),
            signatureAlgorithm: SignatureAlgorithm(rawValue: signatureAlgorithm)!
        )

        // Create a new account
        let account = Account(payer: self.auth)

        // Add the public key to the account
        account.keys.add(
            publicKey: publicKey,
            hashAlgorithm: HashAlgorithm(rawValue: hashAlgorithm)!,
            weight: weight
        )

        // Create a new COA
        let coa <- EVM.createCadenceOwnedAccount()

        // Save the COA to the new account
        let storagePath = StoragePath(identifier: "evm")!
        let publicPath = PublicPath(identifier: "evm")!
        account.storage.save<@EVM.CadenceOwnedAccount>(<-coa, to: storagePath)
        let addressableCap = account.capabilities.storage.issue<&EVM.CadenceOwnedAccount>(storagePath)
        account.capabilities.unpublish(publicPath)
        account.capabilities.publish(addressableCap, at: publicPath)
    }
}
