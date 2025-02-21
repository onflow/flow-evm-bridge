pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title EVMNativeERC721
 * @dev This contract is a minimal ERC721 implementation demonstrating a simple EVM-native cross-VM
 * NFT implementations where projects deploy both a Cadence & Solidity definition. Movement of 
 * individual NFTs facilitated by Flow's canonical VM bridge.
 * In such cases, NFTs must be distributed in either Cadence or EVM - this is termed the NFT's
 * "native" VM. When moving the NFT into the non-native VM, the bridge implements a mint/escrow
 * pattern, minting if the NFT does not exist and unlocking from escrow if it does.
 * The contract below demonstrates the Solidity implementation for an EVM-native NFT. This token's
 * corresponding example Cadence implementation can be seen as ExampleEVMNativeNFT.cdc in Flow's VM
 * Bridge repo: https://github.com/onflow/flow-evm-bridge
 *
 * For more information on cross-VM NFTs, see Flow's developer documentation as well as
 * FLIP-318: https://github.com/onflow/flips/issues/318
 */
contract EVMNativeERC721 is ERC721, Ownable {
    
    constructor() ERC721("EVMNativeERC721", "EVMXMPL") Ownable(msg.sender) {}

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://example-nft.flow.com/tokenURI/";
    }

    function contractURI() public pure returns (string memory) {
        // schema based on OpenSea's contractURI() guidance: https://docs.opensea.io/docs/contract-level-metadata
        string memory json = '{'
            '"name": "The Example EVM-Native NFT Collection",'
            '"description": "This collection is used as an example to help you develop your next EVM-native cross-VM Flow NFT.",'
            '"image": "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg",'
            '"banner_image": "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg",'
            '"featured_image": "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg",'
            '"external_link": "https://example-nft.flow.com",'
            '"collaborators": []'
            '}';
        return string.concat('data:application/json;utf8,', json);
    }
}