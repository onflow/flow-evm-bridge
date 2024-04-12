import Test
import BlockchainHelpers

import "MetadataViews"

import "Serialize"
import "SerializeMetadata"

access(all) let admin = Test.getAccount(0x0000000000000008)
access(all) let alice = Test.createAccount()

access(all) var mintedBlockHeight: UInt64 = 0

access(all)
fun setup() {
    var err = Test.deployContract(
        name: "ExampleNFT",
        path: "../contracts/example-assets/ExampleNFT.cdc",
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
        name: "SerializeMetadata",
        path: "../contracts/utils/SerializeMetadata.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun testSerializeNFTSucceeds() {
    let setupResult = executeTransaction(
        "../transactions/example-assets/example-nft/setup_collection.cdc",
        [],
        alice
    )
    Test.expect(setupResult, Test.beSucceeded())

    let mintResult = executeTransaction(
        "../transactions/example-assets/example-nft/mint_nft.cdc",
        [alice.address, "ExampleNFT", "Example NFT Collection", "https://flow.com/examplenft.jpg", [], [], []],
        admin
    )
    Test.expect(mintResult, Test.beSucceeded())

    let heightResult = executeScript(
        "../scripts/test/get_block_height.cdc",
        []
    )
    mintedBlockHeight = heightResult.returnValue! as! UInt64
    let heightString = mintedBlockHeight.toString()

    let expectedPrefix = "data:application/json;utf8,{\"name\": \"ExampleNFT\", \"description\": \"Example NFT Collection\", \"image\": \"https://flow.com/examplenft.jpg\", \"external_url\": \"https://example-nft.onflow.org\", "
    let altSuffix1 = "\"attributes\": [{\"trait_type\": \"mintedBlock\", \"value\": \"".concat(heightString).concat("\"},{\"trait_type\": \"foo\", \"value\": \"nil\"}]}")
    let altSuffix2 = "\"attributes\": [{\"trait_type\": \"foo\", \"value\": \"nil\"}]}, {\"trait_type\": \"mintedBlock\", \"value\": \"".concat(heightString).concat("\"}")

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
}

// Returns nil when no displays are provided
access(all)
fun testSerializeNilDisplaysReturnsNil() {
    let serializedResult = SerializeMetadata.serializeFromDisplays(nftDisplay: nil, collectionDisplay: nil)
    Test.assertEqual(nil, serializedResult)
}

// Given just token-level Display, serialize as tokenURI format
access(all)
fun testSerializeNFTDisplaySucceeds() {
    let display = MetadataViews.Display(
        name: "NAME",
        description: "NFT Description",
        thumbnail: MetadataViews.HTTPFile(url: "https://flow.com/examplenft.jpg"),
    )

    let expected = "\"name\": \"NAME\", \"description\": \"NFT Description\", \"image\": \"https://flow.com/examplenft.jpg\""

    let serializedResult = SerializeMetadata.serializeFromDisplays(nftDisplay: display, collectionDisplay: nil)
    Test.assertEqual(expected, serializedResult!)
}

// Given just contract-level Display, serialize as contractURI format
access(all)
fun testSerializeNFTCollectionDisplaySucceeds() {
    let collectionDisplay = MetadataViews.NFTCollectionDisplay(
        name: "NAME",
        description: "NFT Description",
        externalURL: MetadataViews.ExternalURL("https://flow.com"),
        squareImage: MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://flow.com/square_image.jpg"), mediaType: "image"),
        bannerImage: MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://flow.com/square_image.jpg"), mediaType: "image"),
        socials: {}
    )

    let expected = "\"name\": \"NAME\", \"description\": \"NFT Description\", \"image\": \"https://flow.com/square_image.jpg\", \"external_link\": \"https://flow.com\""

    let serializedResult = SerializeMetadata.serializeFromDisplays(nftDisplay: nil, collectionDisplay: collectionDisplay)
    Test.assertEqual(expected, serializedResult!)
}

// Given bol token- & contract-level Displays, serialize as tokenURI format
access(all)
fun testSerializeBothDisplaysSucceeds() {
    let nftDisplay = MetadataViews.Display(
        name: "NAME",
        description: "NFT Description",
        thumbnail: MetadataViews.HTTPFile(url: "https://flow.com/examplenft.jpg"),
    )

    let collectionDisplay = MetadataViews.NFTCollectionDisplay(
        name: "NAME",
        description: "NFT Description",
        externalURL: MetadataViews.ExternalURL("https://flow.com"),
        squareImage: MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://flow.com/square_image.jpg"), mediaType: "image"),
        bannerImage: MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://flow.com/square_image.jpg"), mediaType: "image"),
        socials: {}
    )

    let expected = "\"name\": \"NAME\", \"description\": \"NFT Description\", \"image\": \"https://flow.com/examplenft.jpg\", \"external_url\": \"https://flow.com\""

    let serializedResult = SerializeMetadata.serializeFromDisplays(nftDisplay: nftDisplay, collectionDisplay: collectionDisplay)
    Test.assertEqual(expected, serializedResult!)
}
