// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IFlowEVMBridgeDeployer} from "./interfaces/IFlowEVMBridgeDeployer.sol";
import {FlowEVMBridgedERC721} from "./templates/FlowEVMBridgedERC721.sol";

/**
 * @title FlowEVMBridgedERC721Deployer
 * @dev A contract to deploy FlowEVMBridgedERC721 contracts with named associations to Cadence resource types. Only the
 * delegated deployer can deploy new contracts. This contract is used by the Flow EVM bridge to deploy and define
 * bridged ERC721 tokens which are defined natively in Cadence.
 */
contract FlowEVMBridgedERC721Deployer is IFlowEVMBridgeDeployer, ERC165, Ownable {
    // The address of the delegated deployer who can deploy new contracts
    address public delegatedDeployer;

    /**
     * @dev Event emitted when a new ERC721 contract is deployed via this deployer
     */
    event ERC721Deployed(
        address contractAddress, string name, string symbol, string cadenceNFTAddress, string cadenceNFTIdentifier
    );

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Modifier to check if the caller is the delegated deployer
     */
    modifier onlyDelegatedDeployer() {
        require(msg.sender == delegatedDeployer, "FlowEVMBridgedERC721Deployer: Only delegated deployer can deploy");
        _;
    }

    /**
     * @dev ERC165 introspection
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IFlowEVMBridgeDeployer).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Deploy a new FlowEVMBridgedERC721 contract with the given name, symbol, and association to a Cadence
     * contract.
     *
     * @param name The name of the ERC721
     * @param symbol The symbol of the ERC721
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
        FlowEVMBridgedERC721 newERC721 =
            new FlowEVMBridgedERC721(super.owner(), name, symbol, cadenceAddress, cadenceIdentifier, contractURI);

        emit ERC721Deployed(address(newERC721), name, symbol, cadenceAddress, cadenceIdentifier);

        return address(newERC721);
    }

    /**
     * @dev Set the address of the delegated deployer
     *
     * @param _delegatedDeployer The address of the delegated deployer
     */
    function setDelegatedDeployer(address _delegatedDeployer) external onlyOwner {
        require(_delegatedDeployer != address(0), "FlowEVMBridgedERC721Deployer: Invalid delegated deployer address");
        delegatedDeployer = _delegatedDeployer;
    }
}
