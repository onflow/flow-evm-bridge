// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FlowBridgedERC721.sol";

// PROTO: Address - 522b3294e6d06aa25ad0f1b8891242e335d3b459
contract FlowBridgeFactory is Ownable {
    mapping(string => address) public flowIdentifierToContract;
    mapping(address => string) public contractToflowIdentifier;

    constructor() Ownable(msg.sender) {}

    event ERC721Deployed(
        address contractAddress, string name, string symbol, string flowNFTAddress, string flowNFTIdentifier
    );

    // Function to deploy a new ERC721 contract
    function deployERC721(
        string memory name,
        string memory symbol,
        string memory flowNFTAddress,
        string memory flowNFTIdentifier
    ) public onlyOwner returns (address) {
        FlowBridgedERC721 newERC721 =
            new FlowBridgedERC721(super.owner(), name, symbol, flowNFTAddress, flowNFTIdentifier);

        flowIdentifierToContract[flowNFTIdentifier] = address(newERC721);
        contractToflowIdentifier[address(newERC721)] = flowNFTIdentifier;

        emit ERC721Deployed(address(newERC721), name, symbol, flowNFTAddress, flowNFTIdentifier);

        return address(newERC721);
    }

    function isFactoryDeployed(address contractAddr) public view returns (bool) {
        return bytes(contractToflowIdentifier[contractAddr]).length != 0;
    }

    function getFlowAssetIdentifier(address contractAddr) public view returns (string memory) {
        return contractToflowIdentifier[contractAddr];
    }
}
