// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./FlowEVMDeploymentRegistry.sol";

contract FlowBridgeDeploymentRegistry is FlowEVMDeploymentRegistry, Ownable {
    constructor() Ownable(msg.sender) {
        registrar = msg.sender;
    }

    function setRegistrar(address _registrar) external onlyOwner {
        _setRegistrar(_registrar);
    }
}
