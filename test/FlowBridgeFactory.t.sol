// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {FlowBridgeFactory} from "../src/FlowBridgeFactory.sol";
import {FlowBridgedERC721} from "../src/FlowBridgedERC721.sol";

contract FlowBridgeFactoryTest is Test {
    FlowBridgeFactory public factory;
    FlowBridgedERC721 public deployedERC721Contract;

    string name;
    string symbol;
    string flowNFTAddress;
    string flowNFTIdentifier;
    address deployedERC721Address;

    function setUp() public {
        factory = new FlowBridgeFactory();
        name = "name";
        symbol = "symbol";
        flowNFTAddress = "flowNFTAddress";
        flowNFTIdentifier = "flowNFTIdentifier";

        deployedERC721Address = factory.deployERC721("name", "symbol", "flowNFTAddress", "flowNFTIdentifier");
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

        assertEq(actualName, name);
        assertEq(_symbol, symbol);
        assertEq(_flowNFTAddress, flowNFTAddress);
        assertEq(_flowNFTIdentifier, flowNFTIdentifier);

        address factoryOwner = factory.owner();
        address erc721Owner = deployedERC721Contract.owner();
        assertEq(factoryOwner, erc721Owner);
    }
}
