// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import {CrossVMBridgeCallable} from "./CrossVMBridgeCallable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

abstract contract CrossVMBridgeFulfillment is CrossVMBridgeCallable, ERC721 {

    error FulfillmentFailedTokenNotEscrowed(uint256 id, address escrowAddress);

    /**
     * Initializes the bridge EVM address such that only the bridge COA can call privileged methods
     */
    constructor(address _vmBridgeAddress) CrossVMBridgeCallable(_vmBridgeAddress) {}

    /**
     * @dev Fulfills the bridge request, minting (if non-existent) or transferring (if escrowed) the
     * token with the given ID to the provided address. For dynamic metadata handling between
     * Cadence & EVM, implementations should override and assign metadata as encoded from Cadence
     * side. If overriding, be sure to preserve the mint/escrow pattern as shown in the default
     * implementation.
     * 
     * @param _to address of the token recipient
     * @param _id the id of the token being moved into EVM from Cadence
     * @param _data any encoded metadata passed by the corresponding Cadence NFT at the time of
     *      bridging into EVM
     */
    function fulfillToEVM(address _to, uint256 _id, bytes memory _data) external onlyVMBridge {
        if (_ownerOf(_id) == address(0)) {
            _mint(_to, _id); // Doesn't exist, mint the token
        } else {
            // Should be escrowed under vm bridge - transfer from escrow to recipient
            _requireEscrowed(_id);
            safeTransferFrom(vmBridgeAddress(), _to, _id);
        }
    }

    /**
     * @dev Allows a caller to determine the contract conforms to the `ICrossVMFulfillment` interface
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return true; // tmp
    }

    /**
     * @dev Internal method that reverts with FulfillmentFailedTokenNotEscrowed if the provided
     * token is not escrowed with the assigned vm bridge address as owner.
     * 
     * @param _id the token id that must be escrowed
     */
    function _requireEscrowed(uint256 _id) internal view {
        address owner = _ownerOf(_id);
        address vmBridgeAddress_ = vmBridgeAddress();
        if (owner != vmBridgeAddress_) {
            revert FulfillmentFailedTokenNotEscrowed(_id, vmBridgeAddress_);
        }
    }
}