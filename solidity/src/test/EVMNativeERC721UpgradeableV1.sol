// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title EVMNativeERC721UpgradeableV1
 * @dev This is a test contract used to ensure Flow VM bridge can handle ERC721 contracts updated
 * to conform to the FLIP-318 Cross-VM NFT standard. This V1 contract lacks the ICrossVM conformance
 * required for cross-VM NFT registration with the VM bridge.
 */
contract EVMNativeERC721UpgradeableV1 is Initializable, UUPSUpgradeable, ERC721Upgradeable, OwnableUpgradeable {
    string internal contractMetadata;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        address owner,
        string memory _contractMetadata
    ) public initializer onlyProxy {
        __ERC721_init(_name, _symbol);
        __Ownable_init(owner);
        __UUPSUpgradeable_init();
        contractMetadata = _contractMetadata;
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}
