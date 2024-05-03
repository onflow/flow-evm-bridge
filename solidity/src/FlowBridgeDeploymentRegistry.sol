// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./interfaces/FlowEVMDeploymentRegistry.sol";

/**
 * @title FlowBridgeDeploymentRegistry
 * @dev A contract to manage the deployment of Flow EVM contracts and their association with Cadence contracts
 */
contract FlowBridgeDeploymentRegistry is FlowEVMDeploymentRegistry, Ownable {
    constructor() Ownable(msg.sender) {
        registrar = msg.sender;
    }

    /**
     * @dev Set the registrar address as the entity that can register new deployments. Only the owner can call this
     * function.
     *
     * @param _registrar The address of the registrar
     */
    function setRegistrar(address _registrar) external onlyOwner {
        _setRegistrar(_registrar);
    }
}
