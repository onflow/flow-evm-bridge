// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {CrossVMUpgradable} from "./CrossVMUpgradable.sol";

/**
 * @title EVMNativeERC721UpgradeableV2
 * @dev This is a test contract used to ensure Flow VM bridge can handle ERC721 contracts updated
 * to conform to the FLIP-318 Cross-VM NFT standard. This V2 contract implements the ICrossVM 
 * conformance (via CrossVMUpgradable) required for cross-VM NFT registration with the VM bridge.
 */
contract EVMNativeERC721UpgradeableV2 is Initializable, UUPSUpgradeable, ERC721Upgradeable, OwnableUpgradeable, CrossVMUpgradable {
    string internal contractMetadata;

    constructor() {
        _disableInitializers();
    }

    function initializeV2(
        string memory _cadenceNFTAddress,
        string memory _cadenceNFTIdentifier
    ) public reinitializer(2) onlyProxy {
        __CrossVMUpgradable_init(_cadenceNFTAddress, _cadenceNFTIdentifier);
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}
