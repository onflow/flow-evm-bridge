pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {ICrossVM} from "../src/interfaces/ICrossVM.sol";
import {EVMNativeERC721UpgradeableV1} from "../src/test/EVMNativeERC721UpgradeableV1.sol";
import {EVMNativeERC721UpgradeableV2} from "../src/test/EVMNativeERC721UpgradeableV2.sol";

contract EVMNativeERC721UpgradeableTest is Test {
    EVMNativeERC721UpgradeableV1 internal v1;
    EVMNativeERC721UpgradeableV2 internal v2;
    ERC1967Proxy internal proxy;

    address internal v1Impl;
    address internal v2Impl;

    address owner;
    string name;
    string symbol;
    string contractMetadata;
    string cadenceAddress;
    string cadenceIdentifier;

    address recipient;
    uint256 mintId;

    function setUp() public {
        owner = address(100);
        name = "EVMNativeERC721";
        symbol = "EVMXMPL";
        contractMetadata = 'data:application/json;utf8,{"name": "EVMNativeERC721", "symbol": "EVMXMPL"}';
        cadenceAddress = "0xf8d6e0586b0a20c7"; // example Cadence contract address
        cadenceIdentifier = "A.f8d6e0586b0a20c7.ExampleCadenceNativeNFT.NFT"; // example Cadence NFT Type identifier

        recipient = address(101);
        mintId = 42;

        vm.expectEmit();
        emit Initializable.Initialized(type(uint64).max);
        v1 = new EVMNativeERC721UpgradeableV1();
        proxy = new ERC1967Proxy(
                address(v1),
                abi.encodeCall(EVMNativeERC721UpgradeableV1.initialize, (name, symbol, owner, contractMetadata))
            );
        
        v1 = EVMNativeERC721UpgradeableV1(address(proxy));
    }

    function test_initializeEVMNativeERC721UpgradeableV1Succeeds() public {
        string memory name_ = v1.name();
        string memory symbol_ = v1.symbol();
        string memory contractMetadata_ = v1.contractURI();
        address owner_ = v1.owner();

        vm.assertEq(name, name_);
        vm.assertEq(symbol, symbol_);
        vm.assertEq(contractMetadata, contractMetadata_);
        vm.assertEq(owner, owner_);

        // ensure minting funtionality
        vm.prank(owner);
        v1.safeMint(recipient, mintId);

        vm.assertEq(v1.ownerOf(mintId), recipient);
    }

    function test_upgradeToV2Succeeds() public {
        vm.prank(owner);
        v1.safeMint(recipient, mintId);
        vm.assertEq(v1.ownerOf(mintId), recipient);

        v2 = new EVMNativeERC721UpgradeableV2(); // deploy v2
        vm.expectEmit();
        emit IERC1967.Upgraded(address(v2));
        vm.prank(owner);
        // execute the upgrade
        v1.upgradeToAndCall(
            address(v2),
            abi.encodeCall(EVMNativeERC721UpgradeableV2.initializeV2, (cadenceAddress, cadenceIdentifier))
        );
        v2 = EVMNativeERC721UpgradeableV2(address(proxy)); // establish v2 via the existing proxy

        // ensure new & existing fields are initialized properly & v2 is accessible via the proxy
        string memory name_ = v2.name();
        string memory symbol_ = v2.symbol();
        string memory contractMetadata_ = v2.contractURI();
        address owner_ = v2.owner();
        string memory cadenceAddress_ = v2.getCadenceAddress();
        string memory cadenceIdentifier_ = v2.getCadenceIdentifier();

        vm.assertEq(name, name_);
        vm.assertEq(symbol, symbol_);
        vm.assertEq(contractMetadata, contractMetadata_);
        vm.assertEq(owner, owner_);
        vm.assertEq(cadenceAddress, cadenceAddress_);
        vm.assertEq(cadenceIdentifier, cadenceIdentifier_);

        // ensure ownership retained post-upgrade
        vm.assertEq(v2.ownerOf(mintId), recipient);
    }
}