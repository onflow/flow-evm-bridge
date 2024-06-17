// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ICrossVM} from "../interfaces/ICrossVM.sol";

contract FlowEVMBridgedERC20 is ERC20, ERC20Burnable, ERC20Permit, Ownable, ICrossVM {
    string public cadenceTokenAddress;
    string public cadenceTokenIdentifier;
    string public contractMetadata;

    constructor(
        address owner,
        string memory name,
        string memory symbol,
        string memory _cadenceTokenAddress,
        string memory _cadenceTokenIdentifier,
        string memory _contractMetadata
    ) ERC20(name, symbol) Ownable(owner) ERC20Permit(name) {
        cadenceTokenAddress = _cadenceTokenAddress;
        cadenceTokenIdentifier = _cadenceTokenIdentifier;
        contractMetadata = _contractMetadata;
    }

    function getCadenceAddress() external view returns (string memory) {
        return cadenceTokenAddress;
    }

    function getCadenceIdentifier() external view returns (string memory) {
        return cadenceTokenIdentifier;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }
}
