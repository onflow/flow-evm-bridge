// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./FlowBridgedERC721.sol";
import "./FlowBridgedERC20.sol";
import "./IBridgePermissions.sol";

contract FlowBridgeFactory is Ownable {
    mapping(string => address) public flowIdentifierToContract;
    mapping(address => string) public contractToflowIdentifier;

    constructor() Ownable(msg.sender) {}

    event ERC20Deployed(
        address contractAddress, string name, string symbol, string flowTokenAddress, string flowTokenIdentifier
    );
    event ERC721Deployed(
        address contractAddress, string name, string symbol, string flowNFTAddress, string flowNFTIdentifier
    );

    // Function to deploy a new ERC721 contract
    function deployERC20(
        string memory name,
        string memory symbol,
        string memory flowTokenAddress,
        string memory flowTokenIdentifier,
        string memory contractURI
    ) public onlyOwner returns (address) {
        FlowBridgedERC20 newERC20 =
            new FlowBridgedERC20(super.owner(), name, symbol, flowTokenAddress, flowTokenIdentifier, contractURI);

        flowIdentifierToContract[flowTokenIdentifier] = address(newERC20);
        contractToflowIdentifier[address(newERC20)] = flowTokenIdentifier;

        emit ERC20Deployed(address(newERC20), name, symbol, flowTokenAddress, flowTokenIdentifier);

        return address(newERC20);
    }

    // Function to deploy a new ERC721 contract
    function deployERC721(
        string memory name,
        string memory symbol,
        string memory flowNFTAddress,
        string memory flowNFTIdentifier,
        string memory contractURI
    ) public onlyOwner returns (address) {
        FlowBridgedERC721 newERC721 =
            new FlowBridgedERC721(super.owner(), name, symbol, flowNFTAddress, flowNFTIdentifier, contractURI);

        flowIdentifierToContract[flowNFTIdentifier] = address(newERC721);
        contractToflowIdentifier[address(newERC721)] = flowNFTIdentifier;

        emit ERC721Deployed(address(newERC721), name, symbol, flowNFTAddress, flowNFTIdentifier);

        return address(newERC721);
    }

    function getFlowAssetIdentifier(address contractAddr) public view returns (string memory) {
        return contractToflowIdentifier[contractAddr];
    }

    function getContractAddress(string memory flowNFTIdentifier) public view returns (address) {
        return flowIdentifierToContract[flowNFTIdentifier];
    }

    function isFactoryDeployed(address contractAddr) public view returns (bool) {
        return bytes(contractToflowIdentifier[contractAddr]).length != 0;
    }

    function isERC20(address contractAddr) public view returns (bool) {
        (bool success, bytes memory data) = contractAddr.staticcall(abi.encodeWithSignature("totalSupply()"));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) = contractAddr.staticcall(abi.encodeWithSignature("balanceOf(address)", address(0)));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) =
            contractAddr.staticcall(abi.encodeWithSignature("allowance(address,address)", address(0), address(0)));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) = contractAddr.staticcall(abi.encodeWithSignature("name()"));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) = contractAddr.staticcall(abi.encodeWithSignature("symbol()"));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) = contractAddr.staticcall(abi.encodeWithSignature("decimals()"));
        if (!success || data.length == 0) {
            return false;
        }
        return true;
    }

    function isERC721(address contractAddr) public view returns (bool) {
        try ERC165(contractAddr).supportsInterface(0x80ac58cd) returns (bool support) {
            return support;
        } catch {
            return false;
        }
    }
}
