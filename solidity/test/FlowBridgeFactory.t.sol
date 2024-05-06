// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {FlowBridgeDeploymentRegistry} from "../src/FlowBridgeDeploymentRegistry.sol";
import {FlowEVMBridgedERC721Deployer} from "../src/FlowEVMBridgedERC721Deployer.sol";
import {FlowEVMBridgedERC20Deployer} from "../src/FlowEVMBridgedERC20Deployer.sol";
import {FlowBridgeFactory} from "../src/FlowBridgeFactory.sol";
import {FlowEVMBridgedERC721} from "../src/templates/FlowEVMBridgedERC721.sol";
import {FlowEVMBridgedERC20} from "../src/templates/FlowEVMBridgedERC20.sol";

contract FlowBridgeFactoryTest is Test {
    FlowBridgeFactory internal factory;
    FlowBridgeDeploymentRegistry internal registry;
    FlowEVMBridgedERC20Deployer internal erc20Deployer;
    FlowEVMBridgedERC721Deployer internal erc721Deployer;
    FlowEVMBridgedERC20 internal deployedERC20Contract;
    FlowEVMBridgedERC721 internal deployedERC721Contract;

    string name;
    string symbol;
    string flowNFTAddress;
    string flowNFTIdentifier;
    string flowTokenAddress;
    string flowTokenIdentifier;
    string contractURI;
    address deployedERC20Address;
    address deployedERC721Address;

    function setUp() public virtual {
        name = "name";
        symbol = "symbol";
        flowNFTAddress = "flowNFTAddress";
        flowNFTIdentifier = "flowNFTIdentifier";
        flowTokenAddress = "flowTokenAddress";
        flowTokenIdentifier = "flowTokenIdentifier";
        contractURI = "contractURI";

        factory = new FlowBridgeFactory();

        registry = new FlowBridgeDeploymentRegistry();
        erc20Deployer = new FlowEVMBridgedERC20Deployer();
        erc721Deployer = new FlowEVMBridgedERC721Deployer();

        factory.setDeploymentRegistry(address(registry));
        registry.setRegistrar(address(factory));

        erc20Deployer.setDelegatedDeployer(address(factory));
        erc721Deployer.setDelegatedDeployer(address(factory));

        factory.addDeployer("ERC20", address(erc20Deployer));
        factory.addDeployer("ERC721", address(erc721Deployer));

        deployedERC20Address = factory.deploy("ERC20", name, symbol, flowTokenAddress, flowTokenIdentifier, contractURI);
        deployedERC721Address = factory.deploy("ERC721", name, symbol, flowNFTAddress, flowNFTIdentifier, contractURI);

        deployedERC20Contract = FlowEVMBridgedERC20(deployedERC20Address);
        deployedERC721Contract = FlowEVMBridgedERC721(deployedERC721Address);
    }

    function test_RegistryIsNonZero() public {
        address registryAddress = factory.getRegistry();
        assertNotEq(registryAddress, address(0));
    }

    function test_GetERC20Deployer() public {
        address erc20DeployerAddress = factory.getDeployer("ERC20");
        assertEq(erc20DeployerAddress, address(erc20Deployer));
    }

    function test_GetERC721Deployer() public {
        address erc721DeployerAddress = factory.getDeployer("ERC721");
        assertEq(erc721DeployerAddress, address(erc721Deployer));
    }

    function test_DeployERC721() public {
        bool isBridgeDeployed = factory.isBridgeDeployed(deployedERC721Address);
        assertEq(isBridgeDeployed, true);
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
        bool isBridgeDeployed = factory.isBridgeDeployed(deployedERC20Address);
        assertEq(isBridgeDeployed, true);
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

    function test_MintERC721() public {
        address recipient = address(27);
        uint256 tokenId = 42;
        string memory uri = "MOCK_URI";
        deployedERC721Contract.safeMint(recipient, tokenId, uri);

        address owner = deployedERC721Contract.ownerOf(tokenId);
        assertEq(owner, recipient);
    }

    function test_MintERC20() public {
        address recipient = address(27);
        uint256 amount = 100e18;
        deployedERC20Contract.mint(recipient, amount);

        uint256 balance = deployedERC20Contract.balanceOf(recipient);
        assertEq(balance, amount);
    }
}
