// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./IFlowBridgeOptOut.sol";

abstract contract FlowBridgeOptOut is ERC165, IFlowBridgeOptOut {

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IFlowBridgeOptOut).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function confirmOptOut() public view virtual returns (bool) {
        return true;
    }
}