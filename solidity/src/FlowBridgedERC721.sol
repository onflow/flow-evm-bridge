// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// TODO: Implement extensions ERC721Upgradable, Metadata, Enumerable, URIStorage, Royalty etc.
contract FlowBridgedERC721 is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    string public flowNFTAddress;
    string public flowNFTIdentifier;
    string public contractMetadata;

    constructor(
        address owner,
        string memory name,
        string memory symbol,
        string memory _flowNFTAddress,
        string memory _flowNFTIdentifier,
        string memory _contractMetadata
    ) ERC721(name, symbol) Ownable(owner) {
        flowNFTAddress = _flowNFTAddress;
        flowNFTIdentifier = _flowNFTIdentifier;
        contractMetadata = _contractMetadata;
    }

    function safeMint(address to, uint256 tokenId, string memory uri) public onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getFlowNFTAddress() public view returns (string memory) {
        return flowNFTAddress;
    }

    function getFlowNFTIdentifier() public view returns (string memory) {
        return flowNFTIdentifier;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
