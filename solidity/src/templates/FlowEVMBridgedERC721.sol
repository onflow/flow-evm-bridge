// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICrossVM} from "../interfaces/ICrossVM.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract FlowEVMBridgedERC721 is ERC721, ERC721URIStorage, ERC721Burnable, ERC721Enumerable, Ownable, ICrossVM {
    string public cadenceNFTAddress;
    string public cadenceNFTIdentifier;
    string public contractMetadata;

    string private _customSymbol;

    constructor(
        address owner,
        string memory name_,
        string memory symbol_,
        string memory _cadenceNFTAddress,
        string memory _cadenceNFTIdentifier,
        string memory _contractMetadata
    ) ERC721(name_, symbol_) Ownable(owner) {
        _customSymbol = symbol_;
        cadenceNFTAddress = _cadenceNFTAddress;
        cadenceNFTIdentifier = _cadenceNFTIdentifier;
        contractMetadata = _contractMetadata;
    }

    function getCadenceAddress() external view returns (string memory) {
        return cadenceNFTAddress;
    }

    function getCadenceIdentifier() external view returns (string memory) {
        return cadenceNFTIdentifier;
    }

    function symbol() public view override returns (string memory) {
        return _customSymbol;
    }

    function safeMint(address to, uint256 tokenId, string memory uri) public onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function updateTokenURI(uint256 tokenId, string memory uri) public onlyOwner {
        _setTokenURI(tokenId, uri);
    }

    function setSymbol(string memory newSymbol) public onlyOwner {
        _setSymbol(newSymbol);
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721Metadata).interfaceId
            || interfaceId == type(IERC721Enumerable).interfaceId || interfaceId == type(ERC721Burnable).interfaceId
            || interfaceId == type(Ownable).interfaceId || interfaceId == type(ICrossVM).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function _setSymbol(string memory newSymbol) internal {
        _customSymbol = newSymbol;
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }
}
