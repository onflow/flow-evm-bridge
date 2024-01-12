// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FlowBridgedERC721.sol";

contract FlowBridgeFactory is Ownable {
    mapping(string => address) public crossVMNFTContracts;

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
        FlowBridgedERC721 newERC721 = new FlowBridgedERC721(name, symbol, flowNFTAddress, flowNFTIdentifier);

        crossVMNFTContracts[flowNFTIdentifier] = address(newERC721);

        emit ERC721Deployed(address(newERC721), name, symbol, flowNFTAddress, flowNFTIdentifier);

        return address(newERC721);
    }
}
