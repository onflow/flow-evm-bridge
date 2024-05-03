// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./interfaces/IBridgePermissions.sol";
import "./FlowEVMDeploymentRegistry.sol";
import "./interfaces/IFlowEVMBridgeDeployer.sol";

contract FlowBridgeFactory is Ownable {
    address public deploymentRegistry;
    mapping(string => address) public deployers;

    constructor() Ownable(msg.sender) {}

    function deploy(
        string memory tag,
        string memory name,
        string memory symbol,
        string memory cadenceAddress,
        string memory cadenceIdentifier,
        string memory contractURI
    ) public onlyOwner returns (address) {
        address deployerAddress = deployers[tag];
        _requireIsValidDeployer(deployerAddress);
        IFlowEVMBridgeDeployer deployer = IFlowEVMBridgeDeployer(deployerAddress);

        address newContract = deployer.deploy(name, symbol, cadenceAddress, cadenceIdentifier, contractURI);

        _registerDeployment(cadenceIdentifier, newContract);

        return newContract;
    }

    function getCadenceIdentifier(address contractAddr) public view returns (string memory) {
        return FlowEVMDeploymentRegistry(deploymentRegistry).getCadenceIdentifier(contractAddr);
    }

    function getContractAddress(string memory cadenceIdentifier) public view returns (address) {
        return FlowEVMDeploymentRegistry(deploymentRegistry).getContractAddress(cadenceIdentifier);
    }

    function isBridgeDeployed(address contractAddr) public view returns (bool) {
        return FlowEVMDeploymentRegistry(deploymentRegistry).isRegisteredDeployment(contractAddr);
    }

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

    function isERC721(address contractAddr) public view returns (bool) {
        try ERC165(contractAddr).supportsInterface(0x80ac58cd) returns (bool support) {
            return support;
        } catch {
            return false;
        }
    }

    function getRegistry() public view returns (address) {
        return deploymentRegistry;
    }

    function getDeployer(string memory tag) public view returns (address) {
        return deployers[tag];
    }

    function setDeploymentRegistry(address _deploymentRegistry) external onlyOwner {
        _requireIsValidRegistry(_deploymentRegistry);
        deploymentRegistry = _deploymentRegistry;
    }

    function addDeployer(string memory tag, address deployerAddress) external onlyOwner {
        _requireIsValidDeployer(deployerAddress);
        require(deployers[tag] == address(0), "FlowBridgeFactory: Deployer already registered");
        deployers[tag] = deployerAddress;
    }

    function upsertDeployer(string memory tag, address deployerAddress) external onlyOwner {
        _requireIsValidDeployer(deployerAddress);
        deployers[tag] = deployerAddress;
    }

    function _registerDeployment(string memory cadenceIdentifier, address contractAddr) private {
        FlowEVMDeploymentRegistry registry = FlowEVMDeploymentRegistry(deploymentRegistry);
        registry.registerDeployment(cadenceIdentifier, contractAddr);
    }

    function _requireIsValidRegistry(address registryAddr) internal view {
        _requireNotZeroAddress(registryAddr);
        require(
            _implementsInterface(registryAddr, type(IFlowEVMDeploymentRegistry).interfaceId),
            "FlowBridgeFactory: Invalid registry"
        );
    }

    function _requireIsValidDeployer(address contractAddr) internal view {
        _requireNotZeroAddress(contractAddr);
        require(
            _implementsInterface(contractAddr, type(IFlowEVMBridgeDeployer).interfaceId),
            "FlowBridgeFactory: Invalid deployer"
        );
    }

    function _implementsInterface(address contractAddr, bytes4 interfaceId) internal view returns (bool) {
        try ERC165(contractAddr).supportsInterface(interfaceId) returns (bool support) {
            return support;
        } catch {
            return false;
        }
    }

    function _requireNotZeroAddress(address addr) internal pure {
        require(addr != address(0), "FlowBridgeFactory: Zero address");
    }
}
