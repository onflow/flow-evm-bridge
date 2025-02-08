// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title CrossVMBridgeCallable
 * @dev A base contract intended for use in implementations on Flow, allowing a contract to define
 *      access to the Cadence X EVM bridge on certain methods.
 */
abstract contract CrossVMBridgeCallable is Context, IERC165 {

    address private _vmBridgeAddress;

    error CrossVMBridgeCallableZeroInitialization();
    error CrossVMBridgeCallableUnauthorizedAccount(address account);

    /**
     * @dev Sets the bridge EVM address such that only the bridge COA can call the privileged methods
     */
    constructor(address vmBridgeAddress) {
        if (vmBridgeAddress != address(0)) {
            revert CrossVMBridgeCallableZeroInitialization();
        }
        _vmBridgeAddress = vmBridgeAddress;
    }

    /**
     * @dev Modifier restricting access to the designated VM bridge EVM address 
     */
    modifier onlyVMBridge() {
        _checkVMBridgeAddress();
        _;
    }

    /**
     * @dev Returns the designated VM bridge’s EVM address
     */
    function vmBridgeAddress() public view virtual returns (address) {
        return _vmBridgeAddress;
    }

    /**
     * @dev Checks that msg.sender is the designated vm bridge address
     */
    function _checkVMBridgeAddress() internal view virtual {
        if (vmBridgeAddress() != _msgSender()) {
            revert CrossVMBridgeCallableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Allows a caller to determine the contract conforms to the `CrossVMFulfillment` interface
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(CrossVMBridgeCallable).interfaceId;
    }
}