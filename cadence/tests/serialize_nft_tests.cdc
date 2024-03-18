import Test
import BlockchainHelpers

import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"

import "Serialize"
import "SerializationInterfaces"

access(all)
let admin = Test.getAccount(0x0000000000000007)
access(all)
let alice = Test.createAccount()

access(all)
fun setup() {
    var err = Test.deployContract(
        name: "ViewResolver",
        path: "../contracts/standards/ViewResolver.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "Burner",
        path: "../contracts/standards/Burner.cdc",
        arguments: []
    )
    err = Test.deployContract(
        name: "FungibleToken",
        path: "../contracts/standards/FungibleToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "NonFungibleToken",
        path: "../contracts/standards/NonFungibleToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "MetadataViews",
        path: "../contracts/standards/MetadataViews.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "ExampleNFT",
        path: "../contracts/example-assets/ExampleNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "SerializationInterfaces",
        path: "../contracts/utils/SerializationInterfaces.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "Serialize",
        path: "../contracts/utils/Serialize.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
    err = Test.deployContract(
        name: "SerializeNFT",
        path: "../contracts/utils/SerializeNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun testSerializeNFTSucceeds() {
    let setupResult = executeTransaction(
        "../transactions/example-assets/setup_collection.cdc",
        [],
        alice
    )
    Test.expect(setupResult, Test.beSucceeded())

    let mintResult = executeTransaction(
        "../transactions/example-assets/mint_nft.cdc",
        [alice.address, "ExampleNFT", "Example NFT Collection", "https://flow.com/examplenft.jpg", [], [], []],
        admin
    )
    Test.expect(mintResult, Test.beSucceeded())

    let expectedPrefix = "data:application/json;ascii,{\"name\": \"ExampleNFT\", \"description\": \"Example NFT Collection\", \"image\": \"https://flow.com/examplenft.jpg\", \"external_url\": \"https://example-nft.onflow.org\", "
    let altSuffix1 = "\"attributes\": [{\"trait_type\": \"mintedBlock\", \"value\": \"54\"},{\"trait_type\": \"foo\", \"value\": \"nil\"}]}"
    let altSuffix2 = "\"attributes\": [{\"trait_type\": \"foo\", \"value\": \"nil\"}]}, {\"trait_type\": \"mintedBlock\", \"value\": \"54\"}"

    let idsResult = executeScript(
        "../scripts/nft/get_ids.cdc",
        [alice.address, "cadenceExampleNFTCollection"]
    )
    Test.expect(idsResult, Test.beSucceeded())
    let ids = idsResult.returnValue! as! [UInt64]

    let serializeMetadataResult = executeScript(
        "../scripts/serialize/serialize_nft.cdc",
        [alice.address, "cadenceExampleNFTCollection", ids[0]]
    )
    Test.expect(serializeMetadataResult, Test.beSucceeded())

    let serializedMetadata = serializeMetadataResult.returnValue! as! String

    Test.assertEqual(true, serializedMetadata == expectedPrefix.concat(altSuffix1) || serializedMetadata == expectedPrefix.concat(altSuffix2))
    // Test.assertEqual(serializedMetadata, expectedPrefix.concat(altSuffix1))
}

access(all)
fun testOpenSeaMetadataSerializationStrategySucceeds() {
    let expectedPrefix = "data:application/json;ascii,{\"name\": \"ExampleNFT\", \"description\": \"Example NFT Collection\", \"image\": \"https://flow.com/examplenft.jpg\", \"external_url\": \"https://example-nft.onflow.org\", "
    let altSuffix1 = "\"attributes\": [{\"trait_type\": \"mintedBlock\", \"value\": \"54\"},{\"trait_type\": \"foo\", \"value\": \"nil\"}]}"
    let altSuffix2 = "\"attributes\": [{\"trait_type\": \"foo\", \"value\": \"nil\"}]}, {\"trait_type\": \"mintedBlock\", \"value\": \"54\"}"

    let idsResult = executeScript(
        "../scripts/nft/get_ids.cdc",
        [alice.address, "cadenceExampleNFTCollection"]
    )
    Test.expect(idsResult, Test.beSucceeded())
    let ids = idsResult.returnValue! as! [UInt64]

    let serializeMetadataResult = executeScript(
        "../scripts/serialize/serialize_nft_from_open_sea_strategy.cdc",
        [alice.address, "cadenceExampleNFTCollection", ids[0]]
    )
    Test.expect(serializeMetadataResult, Test.beSucceeded())
}
