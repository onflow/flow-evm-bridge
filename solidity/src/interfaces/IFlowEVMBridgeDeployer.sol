// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IFlowEVMBridgeDeployer is IERC165 {
    // Function to deploy a new CadenceBridgedERC20 contract
    function deploy(
        string memory name,
        string memory symbol,
        string memory cadenceAddress,
        string memory cadenceIdentifier,
        string memory contractURI
    ) external returns (address);
}
