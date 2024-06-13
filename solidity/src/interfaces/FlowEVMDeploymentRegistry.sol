// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IFlowEVMDeploymentRegistry} from "./IFlowEVMDeploymentRegistry.sol";

/**
 * @title FlowEVMDeploymentRegistry
 * @dev A contract to manage the deployment of Flow EVM contracts and their association with Cadence contracts. Only the
 * registrar can register new deployments.
 */
abstract contract FlowEVMDeploymentRegistry is IFlowEVMDeploymentRegistry, ERC165 {
    // The address of the registrar who can register new deployments
    address public registrar;
    // Association between Cadence type identifiers and deployed contract addresses
    mapping(string => address) private cadenceIdentifierToContract;
    // Reverse association between deployed contract addresses and Cadence type identifiers
    mapping(address => string) private contractToCadenceIdentifier;

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "FlowBridgeDeploymentRegistry: Only registrar can register association");
        _;
    }

    /**
     * @dev ERC165 introspection
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IFlowEVMDeploymentRegistry).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Get the Cadence type identifier associated with a contract address
     *
     * @param contractAddr The address of the deployed contract
     *
     * @return The Cadence type identifier
     */
    function getCadenceIdentifier(address contractAddr) external view returns (string memory) {
        return contractToCadenceIdentifier[contractAddr];
    }

    /**
     * @dev Get the contract address associated with a Cadence type identifier
     *
     * @param cadenceIdentifier The Cadence type identifier
     *
     * @return The address of the associated contract
     */
    function getContractAddress(string memory cadenceIdentifier) external view returns (address) {
        return cadenceIdentifierToContract[cadenceIdentifier];
    }

    /**
     * @dev Check if a contract address is a registered deployment
     *
     * @param cadenceIdentifier The Cadence type identifier in question
     *
     * @return True if the contract address is associated with a Cadence type identifier as a registered deployment
     */
    function isRegisteredDeployment(string memory cadenceIdentifier) external view returns (bool) {
        return cadenceIdentifierToContract[cadenceIdentifier] != address(0);
    }

    /**
     * @dev Check if a Cadence type identifier is associated with a registered deployment
     *
     * @param contractAddr The address of the contract in question
     *
     * @return True if the contract address is associated with a Cadence type identifier as a registered deployment
     */
    function isRegisteredDeployment(address contractAddr) external view returns (bool) {
        return bytes(contractToCadenceIdentifier[contractAddr]).length != 0;
    }

    /**
     * @dev Register a new deployment address with the given Cadence type identifier. Can only be called by the
     * current registrar.
     *
     * @param cadenceIdentifier The Cadence type identifier
     * @param contractAddr The address of the deployed contract
     */
    function registerDeployment(string memory cadenceIdentifier, address contractAddr) external onlyRegistrar {
        _registerDeployment(cadenceIdentifier, contractAddr);
    }

    /**
     * @dev Internal function to register a new deployment address with the given Cadence type identifier
     *
     * @param cadenceIdentifier The Cadence type identifier
     * @param contractAddr The address of the deployed contract
     */
    function _registerDeployment(string memory cadenceIdentifier, address contractAddr) internal {
        require(contractAddr != address(0), "FlowEVMDeploymentRegistry: Contract address cannot be 0");
        require(bytes(cadenceIdentifier).length != 0, "FlowEVMDeploymentRegistry: Cadence identifier cannot be empty");
        require(
            cadenceIdentifierToContract[cadenceIdentifier] == address(0),
            "FlowEVMDeploymentRegistry: Cadence identifier already registered"
        );
        require(
            bytes(contractToCadenceIdentifier[contractAddr]).length == 0,
            "FlowEVMDeploymentRegistry: Contract address already registered"
        );

        cadenceIdentifierToContract[cadenceIdentifier] = contractAddr;
        contractToCadenceIdentifier[contractAddr] = cadenceIdentifier;
    }

    /**
     * @dev Set the registrar address as the entity that can register new deployments. Only the owner can execute this.
     */
    function _setRegistrar(address _registrar) internal {
        require(_registrar != address(0), "FlowEVMDeploymentRegistry: Registrar cannot be 0");
        registrar = _registrar;
    }
}
