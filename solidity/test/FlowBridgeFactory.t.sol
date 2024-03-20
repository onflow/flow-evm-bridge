// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {FlowBridgeFactory} from "../src/FlowBridgeFactory.sol";
import {FlowBridgedERC721} from "../src/FlowBridgedERC721.sol";

contract FlowBridgeFactoryTest is Test {
    FlowBridgeFactory internal factory;
    FlowBridgedERC721 internal deployedERC721Contract;

    string name;
    string symbol;
    string flowNFTAddress;
    string flowNFTIdentifier;
    string contractURI;
    address deployedERC721Address;

    function setUp() public virtual {
        factory = new FlowBridgeFactory();
        name = "name";
        symbol = "symbol";
        flowNFTAddress = "flowNFTAddress";
        flowNFTIdentifier = "flowNFTIdentifier";
        contractURI = "contractURI";

        deployedERC721Address = factory.deployERC721(name, symbol, flowNFTAddress, flowNFTIdentifier, contractURI);
        deployedERC721Contract = FlowBridgedERC721(deployedERC721Address);
    }

    function test_DeployERC721() public {
        bool isFactoryDeployed = factory.isFactoryDeployed(deployedERC721Address);
        assertEq(isFactoryDeployed, true);
    }

    function test_ValidateDeployedERC721Address() public {
        string memory actualName = deployedERC721Contract.name();
        string memory _symbol = deployedERC721Contract.symbol();
        string memory _flowNFTAddress = deployedERC721Contract.flowNFTAddress();
        string memory _flowNFTIdentifier = deployedERC721Contract.flowNFTIdentifier();
        string memory _contractURI = deployedERC721Contract.contractURI();

        assertEq(actualName, name);
        assertEq(_symbol, symbol);
        assertEq(_flowNFTAddress, flowNFTAddress);
        assertEq(_flowNFTIdentifier, flowNFTIdentifier);
        assertEq(_contractURI, contractURI);

        address factoryOwner = factory.owner();
        address erc721Owner = deployedERC721Contract.owner();
        assertEq(factoryOwner, erc721Owner);
    }

    function test_SuccessfulMint() public {
        address recipient = address(27);
        uint256 tokenId = 42;
        string memory uri = "MOCK_URI";
        deployedERC721Contract.safeMint(recipient, tokenId, uri);

        address owner = deployedERC721Contract.ownerOf(tokenId);
        assertEq(owner, recipient);
    }
}
