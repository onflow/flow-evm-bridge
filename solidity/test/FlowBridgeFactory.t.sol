// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {FlowBridgeFactory} from "../src/FlowBridgeFactory.sol";
import {FlowBridgedERC721} from "../src/templates/FlowBridgedERC721.sol";
import {FlowBridgedERC20} from "../src/templates/FlowBridgedERC20.sol";

contract FlowBridgeFactoryTest is Test {
    FlowBridgeFactory internal factory;
    FlowBridgedERC721 internal deployedERC721Contract;
    FlowBridgedERC20 internal deployedERC20Contract;

    string name;
    string symbol;
    string flowNFTAddress;
    string flowNFTIdentifier;
    string flowTokenAddress;
    string flowTokenIdentifier;
    string contractURI;
    address deployedERC721Address;
    address deployedERC20Address;

    function setUp() public virtual {
        factory = new FlowBridgeFactory();
        name = "name";
        symbol = "symbol";
        flowNFTAddress = "flowNFTAddress";
        flowNFTIdentifier = "flowNFTIdentifier";
        flowTokenAddress = "flowTokenAddress";
        flowTokenIdentifier = "flowTokenIdentifier";
        contractURI = "contractURI";

        deployedERC721Address = factory.deployERC721(name, symbol, flowNFTAddress, flowNFTIdentifier, contractURI);
        deployedERC20Address = factory.deployERC20(name, symbol, flowTokenAddress, flowTokenIdentifier, contractURI);
        deployedERC721Contract = FlowBridgedERC721(deployedERC721Address);
        deployedERC20Contract = FlowBridgedERC20(deployedERC20Address);
    }

    function test_DeployERC721() public {
        bool isFactoryDeployed = factory.isFactoryDeployed(deployedERC721Address);
        assertEq(isFactoryDeployed, true);
    }

    function test_IsERC721True() public {
        bool isERC721 = factory.isERC721(deployedERC721Address);
        assertEq(isERC721, true);
    }

    function test_IsERC721False() public {
        bool isERC721 = factory.isERC721(deployedERC20Address);
        assertEq(isERC721, false);
    }

    function test_DeployERC20() public {
        bool isFactoryDeployed = factory.isFactoryDeployed(deployedERC20Address);
        assertEq(isFactoryDeployed, true);
    }

    function test_IsERC20True() public {
        bool isERC20 = factory.isERC20(deployedERC20Address);
        assertEq(isERC20, true);
    }

    function test_IsERC20False() public {
        bool isERC20 = factory.isERC20(deployedERC721Address);
        assertEq(isERC20, false);
    }

    function test_ValidateDeployedERC721Address() public {
        string memory _name = deployedERC721Contract.name();
        string memory _symbol = deployedERC721Contract.symbol();
        string memory _flowNFTAddress = deployedERC721Contract.flowNFTAddress();
        string memory _flowNFTIdentifier = deployedERC721Contract.flowNFTIdentifier();
        string memory _contractURI = deployedERC721Contract.contractURI();

        assertEq(_name, name);
        assertEq(_symbol, symbol);
        assertEq(_flowNFTAddress, flowNFTAddress);
        assertEq(_flowNFTIdentifier, flowNFTIdentifier);
        assertEq(_contractURI, contractURI);

        address factoryOwner = factory.owner();
        address erc721Owner = deployedERC721Contract.owner();
        assertEq(factoryOwner, erc721Owner);
    }

    function test_ValidateDeployedERC20Address() public {
        string memory _name = deployedERC20Contract.name();
        string memory _symbol = deployedERC20Contract.symbol();
        string memory _flowTokenAddress = deployedERC20Contract.getFlowTokenAddress();
        string memory _flowTokenIdentifier = deployedERC20Contract.flowTokenIdentifier();
        string memory _contractURI = deployedERC20Contract.contractURI();

        assertEq(_name, name);
        assertEq(_symbol, symbol);
        assertEq(_flowTokenAddress, flowTokenAddress);
        assertEq(_flowTokenIdentifier, flowTokenIdentifier);
        assertEq(_contractURI, contractURI);

        address factoryOwner = factory.owner();
        address erc20Owner = deployedERC20Contract.owner();
        assertEq(factoryOwner, erc20Owner);
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
