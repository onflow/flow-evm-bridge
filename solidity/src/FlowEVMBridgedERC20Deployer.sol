// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IFlowEVMBridgeDeployer} from "./interfaces/IFlowEVMBridgeDeployer.sol";
import {FlowEVMBridgedERC20} from "./templates/FlowEVMBridgedERC20.sol";

/**
 * @title FlowEVMBridgedERC20Deployer
 * @dev A contract to deploy FlowEVMBridgedERC20 contracts with named associations to Cadence resources types. Only the
 * delegated deployer can deploy new contracts. This contract is used by the Flow EVM bridge to deploy and define
 * bridged ERC20 tokens which are defined natively in Cadence.
 */
contract FlowEVMBridgedERC20Deployer is ERC165, IFlowEVMBridgeDeployer, Ownable {
    // The address of the delegated deployer who can deploy new contracts
    address public delegatedDeployer;

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Modifier to check if the caller is the delegated deployer
     */
    modifier onlyDelegatedDeployer() {
        require(msg.sender == delegatedDeployer, "FlowEVMBridgedERC20Deployer: Only delegated deployer can deploy");
        _;
    }

    /**
     * @dev ERC165 introspection
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IFlowEVMBridgeDeployer).interfaceId || interfaceId == type(Ownable).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Deploy a new FlowEVMBridgedERC20 contract with the given name, symbol, and association to a Cadence
     * contract.
     *
     * @param name The name of the ERC20
     * @param symbol The symbol of the ERC20
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
    ) external onlyDelegatedDeployer returns (address) {
        FlowEVMBridgedERC20 newERC20 =
            new FlowEVMBridgedERC20(super.owner(), name, symbol, cadenceAddress, cadenceIdentifier, contractURI);

        emit Deployed(address(newERC20), name, symbol, cadenceAddress, cadenceIdentifier);

        return address(newERC20);
    }

    /**
     * @dev Set the delegated deployer address as the entity that can deploy new contracts. Only the owner can call this
     * function.
     *
     * @param _delegatedDeployer The address of the delegated deployer
     */
    function setDelegatedDeployer(address _delegatedDeployer) external onlyOwner {
        require(_delegatedDeployer != address(0), "FlowEVMBridgedERC20Deployer: Invalid delegated deployer address");
        delegatedDeployer = _delegatedDeployer;

        emit DeployerAuthorized(_delegatedDeployer);
    }
}
