// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IFlowEVMBridgeDeployer
 * @dev Interface contracts on FlowEVM which deploys EVM contracts with named associations to Cadence contracts.
 */
interface IFlowEVMBridgeDeployer is IERC165 {
    /**
     * @dev Event emitted when a new contract is deployed via this deployer
     */
    event Deployed(
        address indexed contractAddress, string name, string symbol, string cadenceAddress, string cadenceIdentifier
    );

    /**
     * @dev Event emitted when a new deployer is authorized
     */
    event DeployerAuthorized(address indexed deployer);

    /**
     * @dev Deploy a new EVM contract with the given name, symbol, and association to a Cadence contract.
     *
     * @param name The name of the EVM asset
     * @param symbol The symbol of the EVM asset
     * @param cadenceAddress The address of the associated Cadence contract
     * @param cadenceIdentifier The identifier of the associated Cadence asset type
     * @param contractURI The URI of the contract metadata
     *
     * @return The address of the deployed EVM contract
     */
    function deploy(
        string memory name,
        string memory symbol,
        string memory cadenceAddress,
        string memory cadenceIdentifier,
        string memory contractURI
    ) external returns (address);
}
