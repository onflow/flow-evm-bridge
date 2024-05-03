// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./interfaces/IFlowEVMDeploymentRegistry.sol";

abstract contract FlowEVMDeploymentRegistry is IFlowEVMDeploymentRegistry, ERC165 {
    address public registrar;
    mapping(string => address) public cadenceIdentifierToContract;
    mapping(address => string) public contractToCadenceIdentifier;

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "FlowBridgeDeploymentRegistry: Only registrar can register association");
        _;
    }

    function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IFlowEVMDeploymentRegistry).interfaceId || super.supportsInterface(interfaceId);
    }

    function getCadenceIdentifier(address contractAddr) external view returns (string memory) {
        return contractToCadenceIdentifier[contractAddr];
    }

    function getContractAddress(string memory cadenceIdentifier) external view returns (address) {
        return cadenceIdentifierToContract[cadenceIdentifier];
    }

    function isRegisteredDeployment(string memory cadenceIdentifier) external view returns (bool) {
        return cadenceIdentifierToContract[cadenceIdentifier] != address(0);
    }

    function isRegisteredDeployment(address contractAddr) external view returns (bool) {
        return bytes(contractToCadenceIdentifier[contractAddr]).length != 0;
    }

    function registerDeployment(string memory cadenceIdentifier, address contractAddr) external onlyRegistrar {
        _registerDeployment(cadenceIdentifier, contractAddr);
    }

    function _registerDeployment(string memory cadenceIdentifier, address contractAddr) internal {
        cadenceIdentifierToContract[cadenceIdentifier] = contractAddr;
        contractToCadenceIdentifier[contractAddr] = cadenceIdentifier;
    }

    function _setRegistrar(address _registrar) internal {
        registrar = _registrar;
    }
}
