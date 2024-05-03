// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IFlowEVMDeploymentRegistry
 * @dev Interface for the FlowEVMDeploymentRegistry contract, intended to be used for contracts that need to manage
 * associations between Flow EVM contracts and Cadence contracts.
 */
interface IFlowEVMDeploymentRegistry is IERC165 {
    /**
     * @dev Get the Cadence type identifier associated with a contract address
     */
    function getCadenceIdentifier(address contractAddr) external view returns (string memory);

    /**
     * @dev Get the contract address associated with a Cadence type identifier
     */
    function getContractAddress(string memory cadenceIdentifier) external view returns (address);

    /**
     * @dev Check if a contract address is associated with a Cadence type identifier
     */
    function isRegisteredDeployment(address contractAddr) external view returns (bool);

    /**
     * @dev Check if a Cadence type identifier is associated with a contract address
     */
    function isRegisteredDeployment(string memory cadenceIdentifier) external view returns (bool);
}
