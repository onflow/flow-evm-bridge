// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICrossVM} from "../interfaces/ICrossVM.sol";

contract FlowEVMBridgedERC20 is ERC165, ERC20, ERC20Burnable, ERC20Permit, Ownable, ICrossVM {
    string public cadenceTokenAddress;
    string public cadenceTokenIdentifier;
    string public contractMetadata;

    string private _customSymbol;

    constructor(
        address owner,
        string memory name_,
        string memory symbol_,
        string memory _cadenceTokenAddress,
        string memory _cadenceTokenIdentifier,
        string memory _contractMetadata
    ) ERC20(name_, symbol_) Ownable(owner) ERC20Permit(name_) {
        _customSymbol = symbol_;
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

    function symbol() public view override returns (string memory) {
        return _customSymbol;
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function setSymbol(string memory newSymbol) public onlyOwner {
        _setSymbol(newSymbol);
    }

    function setContractURI(string memory newContractURI) public onlyOwner {
        contractMetadata = newContractURI;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC165) returns (bool) {
        return interfaceId == type(IERC20).interfaceId || interfaceId == type(ERC20Burnable).interfaceId
            || interfaceId == type(Ownable).interfaceId || interfaceId == type(ERC20Permit).interfaceId
            || interfaceId == type(ICrossVM).interfaceId || super.supportsInterface(interfaceId);
    }

    function _setSymbol(string memory newSymbol) internal {
        _customSymbol = newSymbol;
    }
}
