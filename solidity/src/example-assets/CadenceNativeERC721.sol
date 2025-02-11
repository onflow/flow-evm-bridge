pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {CrossVMBridgeERC721Fulfillment} from "../interfaces/CrossVMBridgeERC721Fulfillment.sol";

contract CadenceNativeERC721 is CrossVMBridgeERC721Fulfillment {
    
    // included to test before & after fulfillment hooks
    uint256 public beforeCounter;
    uint256 public afterCounter;
    
    constructor(
        string memory name_,
        string memory symbol_,
        address _vmBridgeAddress
    ) CrossVMBridgeERC721Fulfillment(_vmBridgeAddress) ERC721(name_, symbol_) {}

    function _beforeFulfillment(address _to, uint256 _id, bytes memory _data) internal override {
        beforeCounter += 1;
    }

    function _afterFulfillment(address _to, uint256 _id, bytes memory _data) internal override {
        afterCounter += 1;
    }
}