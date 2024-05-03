// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./interfaces/IFlowEVMBridgeDeployer.sol";
import "./templates/FlowEVMBridgedERC20.sol";

contract FlowEVMBridgedERC20Deployer is IFlowEVMBridgeDeployer, ERC165, Ownable {
    address public delegatedDeployer;

    constructor() Ownable(msg.sender) {}

    modifier onlyDelegatedDeployer() {
        require(msg.sender == delegatedDeployer, "FlowEVMBridgedERC20Deployer: Only delegated deployer can deploy");
        _;
    }

    event ERC20Deployed(
        address contractAddress, string name, string symbol, string cadenceTokenAddress, string cadenceVaultIdentifier
    );

    function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IFlowEVMBridgeDeployer).interfaceId || super.supportsInterface(interfaceId);
    }

    function deploy(
        string memory name,
        string memory symbol,
        string memory cadenceAddress,
        string memory cadenceIdentifier,
        string memory contractURI
    ) external onlyDelegatedDeployer returns (address) {
        FlowEVMBridgedERC20 newERC20 =
            new FlowEVMBridgedERC20(super.owner(), name, symbol, cadenceAddress, cadenceIdentifier, contractURI);

        emit ERC20Deployed(address(newERC20), name, symbol, cadenceAddress, cadenceIdentifier);

        return address(newERC20);
    }

    function setDelegatedDeployer(address _delegatedDeployer) external onlyOwner {
        require(_delegatedDeployer != address(0), "FlowEVMBridgedERC20Deployer: Invalid delegated deployer address");
        delegatedDeployer = _delegatedDeployer;
    }
}
