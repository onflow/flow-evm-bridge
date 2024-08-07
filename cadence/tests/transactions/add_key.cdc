transaction(pubKey: String) {
    prepare(signer: auth(AddKey) &Account)  {
        signer.keys.add(
            publicKey: PublicKey(
                publicKey: pubKey.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.ECDSA_secp256k1
            ),
            hashAlgorithm: HashAlgorithm.SHA2_256,
            weight: 1000.0
        )
    }
}