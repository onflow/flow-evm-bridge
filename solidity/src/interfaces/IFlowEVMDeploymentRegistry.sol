// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IFlowEVMDeploymentRegistry is IERC165 {
    function getCadenceIdentifier(address contractAddr) external view returns (string memory);

    function getContractAddress(string memory cadenceIdentifier) external view returns (address);

    function isRegisteredDeployment(address contractAddr) external view returns (bool);

    function isRegisteredDeployment(string memory cadenceIdentifier) external view returns (bool);
}
