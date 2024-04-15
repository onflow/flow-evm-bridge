// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract FlowBridgedERC20 is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    string public flowTokenAddress;
    string public flowTokenIdentifier;
    string public contractMetadata;

    constructor(
        address owner,
        string memory name,
        string memory symbol,
        string memory _flowTokenAddress,
        string memory _flowTokenIdentifier,
        string memory _contractMetadata
    ) ERC20(name, symbol) Ownable(owner) ERC20Permit(name) {
        flowTokenAddress = _flowTokenAddress;
        flowTokenIdentifier = _flowTokenIdentifier;
        contractMetadata = _contractMetadata;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function getFlowTokenAddress() public view returns (string memory) {
        return flowTokenAddress;
    }

    function getFlowTokenIdentifier() public view returns (string memory) {
        return flowTokenIdentifier;
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }
}
