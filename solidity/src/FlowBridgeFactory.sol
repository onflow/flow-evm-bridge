// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IBridgePermissions} from "./interfaces/IBridgePermissions.sol";
import {IFlowEVMBridgeDeployer} from "./interfaces/IFlowEVMBridgeDeployer.sol";
import {IFlowEVMDeploymentRegistry} from "./interfaces/IFlowEVMDeploymentRegistry.sol";
import {FlowEVMDeploymentRegistry} from "./interfaces/FlowEVMDeploymentRegistry.sol";

/**
 * @title FlowBridgeFactory
 * @dev Factory contract to deploy new FlowEVM bridge contracts, defining Cadence-native assets in EVM. Cadence & EVM
 * contract associations are maintained in a deployment registry. This factory is enabled to deploy contracts via
 * registered deployer implementations, each of which handle the deployment of a single templated contract indexed by
 * a human-readable deployer tag. This setup modularizes each key component of the EVM side of the Flow EVM VM bridge,
 * allowing new asset types to be added by simply adding a new deployer implementation or updated factory contract
 * to be swapped out without affecting the underlying associations between Cadence and EVM contracts.
 */
contract FlowBridgeFactory is Ownable {
    // Address of the deployment registry where deployed contract associations are registered
    address private deploymentRegistry;
    // Mapping of deployer tags to their implementation addresses
    mapping(string => address) private deployers;

    /**
     * @dev Emitted when a deployer is added to the factory
     */
    event DeployerAdded(string tag, address deployerAddress);
    /**
     * @dev Emitted when a deployer is updated in the factory
     */
    event DeployerUpdated(string tag, address oldAddress, address newAddress);
    /**
     * @dev Emitted when a deployer is removed from the factory
     */
    event DeployerRemoved(string tag, address oldAddress);
    /**
     * @dev Emitted when the deployment registry is updated
     */
    event DeploymentRegistryUpdated(address oldAddress, address newAddress);

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Deploys a new asset contract via a registered deployer
     *
     * @param deployerTag The tag of the deployer to use as set by the owner
     * @param name The name of the asset
     * @param symbol The symbol of the asset
     * @param cadenceAddress The Flow account address of the Cadence implementation
     * @param cadenceIdentifier The Cadence identifier of the asset type
     * @param contractURI The URI of the contract metadata for the asset
     *
     * @return The address of the newly deployed contract
     */
    function deploy(
        string memory deployerTag,
        string memory name,
        string memory symbol,
        string memory cadenceAddress,
        string memory cadenceIdentifier,
        string memory contractURI
    ) public onlyOwner returns (address) {
        address deployerAddress = deployers[deployerTag];
        _requireIsValidDeployer(deployerAddress);
        IFlowEVMBridgeDeployer deployer = IFlowEVMBridgeDeployer(deployerAddress);

        address newContract = deployer.deploy(name, symbol, cadenceAddress, cadenceIdentifier, contractURI);

        _registerDeployment(cadenceIdentifier, newContract);

        return newContract;
    }

    /**
     * @dev Retrieves the Cadence type identifier associated with the bridge-deployed contract
     *
     * @param contractAddr The address of the deployed contract
     *
     * @return The Cadence identifier of the contract
     */
    function getCadenceIdentifier(address contractAddr) public view returns (string memory) {
        return FlowEVMDeploymentRegistry(deploymentRegistry).getCadenceIdentifier(contractAddr);
    }

    /**
     * @dev Retrieves the address of a bridge-deployed contract by its associated Cadence type identifier
     *
     * @param cadenceIdentifier The Cadence type identifier of the contract
     *
     * @return The address of the deployed contract
     */
    function getContractAddress(string memory cadenceIdentifier) public view returns (address) {
        return FlowEVMDeploymentRegistry(deploymentRegistry).getContractAddress(cadenceIdentifier);
    }

    /**
     * @dev Checks if a contract address is associated with a registered deployment
     *
     * @param contractAddr The address of the deployed contract
     *
     * @return True if the contract is a registered deployment, false otherwise
     */
    function isBridgeDeployed(address contractAddr) public view returns (bool) {
        return FlowEVMDeploymentRegistry(deploymentRegistry).isRegisteredDeployment(contractAddr);
    }

    /**
     * @dev Makes a best guess if the contract address is an ERC20 token by calling the publicly accessible ERC20
     * interface methods on the contract via staticcall to prevent reverts. Note, since ERC20 does not implement
     * ERC165, this is a best guess and may result in false positives.
     *
     * @param contractAddr The address of the contract to check
     *
     * @return True if the contract is an ERC20 token, false otherwise
     */
    function isERC20(address contractAddr) public view returns (bool) {
        (bool success, bytes memory data) = contractAddr.staticcall(abi.encodeWithSignature("totalSupply()"));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) = contractAddr.staticcall(abi.encodeWithSignature("balanceOf(address)", address(0)));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) =
            contractAddr.staticcall(abi.encodeWithSignature("allowance(address,address)", address(0), address(0)));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) = contractAddr.staticcall(abi.encodeWithSignature("name()"));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) = contractAddr.staticcall(abi.encodeWithSignature("symbol()"));
        if (!success || data.length == 0) {
            return false;
        }
        (success, data) = contractAddr.staticcall(abi.encodeWithSignature("decimals()"));
        if (!success || data.length == 0) {
            return false;
        }
        return true;
    }

    /**
     * @dev Determines if a contract is an ERC721 token by checking if it implements the ERC721 interface via ERC165
     * supportsInterface call.
     *
     * @param contractAddr The address of the contract to check
     *
     * @return True if the contract is an ERC721 token, false otherwise
     */
    function isERC721(address contractAddr) public view returns (bool) {
        try ERC165(contractAddr).supportsInterface(0x80ac58cd) returns (bool support) {
            return support;
        } catch {
            return false;
        }
    }

    /**
     * @dev Retrieves the address of the deployment registry
     *
     * @return The address of the deployment registry
     */
    function getRegistry() public view returns (address) {
        return deploymentRegistry;
    }

    /**
     * @dev Retrieves the address of a deployer by its tag
     *
     * @param tag The tag of the deployer
     *
     * @return The address of the deployer
     */
    function getDeployer(string memory tag) public view returns (address) {
        return deployers[tag];
    }

    /**
     * @dev Sets the address of the deployment registry
     *
     * @param _deploymentRegistry The address of the deployment registry
     */
    function setDeploymentRegistry(address _deploymentRegistry) public onlyOwner {
        _requireIsValidRegistry(_deploymentRegistry);

        emit DeploymentRegistryUpdated(deploymentRegistry, _deploymentRegistry);

        deploymentRegistry = _deploymentRegistry;
    }

    /**
     * @dev Adds a new deployer to the factory
     *
     * @param tag The tag of the deployer
     * @param deployerAddress The address of the deployer
     *
     * emits a {DeployerAdded} event
     */
    function addDeployer(string memory tag, address deployerAddress) public onlyOwner {
        _requireIsValidDeployer(deployerAddress);
        require(deployers[tag] == address(0), "FlowBridgeFactory: Deployer already registered");
        deployers[tag] = deployerAddress;

        emit DeployerAdded(tag, deployerAddress);
    }

    /**
     * @dev Adds a deployer to the factory, or updates the address of an existing deployer
     *
     * @param tag The tag of the deployer
     *
     * emits a {DeployerUpdated} event if the deployer already exists otherwise a {DeployerAdded} event
     */
    function upsertDeployer(string memory tag, address deployerAddress) public onlyOwner {
        _requireIsValidDeployer(deployerAddress);

        address oldAddress = deployers[tag];
        if (oldAddress == address(0)) {
            addDeployer(tag, deployerAddress);
            return;
        }

        deployers[tag] = deployerAddress;

        emit DeployerUpdated(tag, oldAddress, deployerAddress);
    }

    /**
     * @dev Removes a deployer from the factory
     *
     * @param tag The tag of the deployer
     *
     * emits a {DeployerRemoved} event
     */
    function removeDeployer(string memory tag) public onlyOwner {
        address oldAddress = deployers[tag];
        require(oldAddress != address(0), "FlowBridgeFactory: Deployer not registered");

        delete deployers[tag];

        emit DeployerRemoved(tag, oldAddress);
    }

    /**
     * @dev Registers a new deployment in the deployment registry
     *
     * @param cadenceIdentifier The Cadence identifier of the deployed contract
     * @param contractAddr The address of the deployed contract
     */
    function _registerDeployment(string memory cadenceIdentifier, address contractAddr) internal {
        FlowEVMDeploymentRegistry registry = FlowEVMDeploymentRegistry(deploymentRegistry);
        registry.registerDeployment(cadenceIdentifier, contractAddr);
    }

    /**
     * @dev Asserts that the registry address is non-zero and implements the IFlowEVMDeploymentRegistry interface
     *
     * @param registryAddr The address of the registry to check
     */
    function _requireIsValidRegistry(address registryAddr) internal view {
        _requireNotZeroAddress(registryAddr);
        require(
            _implementsInterface(registryAddr, type(IFlowEVMDeploymentRegistry).interfaceId),
            "FlowBridgeFactory: Invalid registry"
        );
    }

    /**
     * @dev Asserts that the contract address is non-zero and implements the IFlowEVMBridgeDeployer interface
     *
     * @param contractAddr The address of the contract to check
     */
    function _requireIsValidDeployer(address contractAddr) internal view {
        _requireNotZeroAddress(contractAddr);
        require(
            _implementsInterface(contractAddr, type(IFlowEVMBridgeDeployer).interfaceId),
            "FlowBridgeFactory: Invalid deployer"
        );
    }

    /**
     * @dev Checks if a contract implements a specific interface
     *
     * @param contractAddr The address of the contract to check
     *
     * @return True if the contract implements the interface, false otherwise
     */
    function _implementsInterface(address contractAddr, bytes4 interfaceId) internal view returns (bool) {
        try ERC165(contractAddr).supportsInterface(interfaceId) returns (bool support) {
            return support;
        } catch {
            return false;
        }
    }

    /**
     * @dev Asserts that the address is non-zero
     *
     * @param addr The address to check
     */
    function _requireNotZeroAddress(address addr) internal pure {
        require(addr != address(0), "FlowBridgeFactory: Zero address");
    }
}
