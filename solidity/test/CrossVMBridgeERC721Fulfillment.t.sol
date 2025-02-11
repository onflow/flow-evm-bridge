pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {IERC721Errors} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {CrossVMBridgeCallable} from "../src/interfaces/CrossVMBridgeCallable.sol";
import {CadenceNativeERC721} from "../src/example-assets/CadenceNativeERC721.sol";
import {ICrossVMBridgeERC721Fulfillment} from "../src/interfaces/ICrossVMBridgeERC721Fulfillment.sol";
import {CrossVMBridgeERC721Fulfillment} from "../src/interfaces/CrossVMBridgeERC721Fulfillment.sol";

contract CrossVMBridgeERC721FulfillmentTest is Test {
    CadenceNativeERC721 internal erc721Impl;

    string name;
    string symbol;
    address vmBridge;

    address recipient;

    uint256 fulfilledId;
    bytes emptyBytes;

    function setUp() public {
        name = "name";
        symbol = "symbol";

        vmBridge = address(100);
        recipient = address(101);

        fulfilledId = 42;
        emptyBytes = new bytes(0);

        erc721Impl = new CadenceNativeERC721(name, symbol, vmBridge);
    }

    function test_VMBridgeAddressMatches() public view {
        address actualVMBridge = erc721Impl.vmBridgeAddress();
        assertEq(vmBridge, actualVMBridge);
    }

    function test_FulfillToEVMAsUnauthorizedFails() public {
        vm.prank(recipient);
        vm.expectRevert(
            abi.encodeWithSelector(CrossVMBridgeCallable.CrossVMBridgeCallableUnauthorizedAccount.selector, recipient)
        );
        CrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, emptyBytes);
    }

    function test_FulfillToEVMMintSucceeds() public {
        // Ensure fulfilledId is nonexistent
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, fulfilledId)
        );
        erc721Impl.ownerOf(fulfilledId);

        // Check current counter values
        uint256 beforeCounter = erc721Impl.beforeCounter();
        uint256 afterCounter = erc721Impl.afterCounter();

        // Call fulfillToEVM minting fulfilledId & incrementing before and after counters
        vm.expectEmit();
        emit CrossVMBridgeERC721Fulfillment.FulfilledToEVM(recipient, fulfilledId);

        vm.prank(vmBridge);
        CrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, emptyBytes);

        // Confirm id was fulfilled to recipient
        address ownerOf = erc721Impl.ownerOf(fulfilledId);
        assertEq(recipient, ownerOf);

        // Confirm overridden before & after hooks executed
        uint256 postFulfillmentBeforeCounter = erc721Impl.beforeCounter();
        uint256 postFulfillmentAfterCounter = erc721Impl.afterCounter();
        assertEq(postFulfillmentBeforeCounter, beforeCounter + 1);
        assertEq(postFulfillmentAfterCounter, afterCounter + 1);
    }

    function test_FulfillToEVMUnescrowedFails() public {
        // Ensure fulfilledId is nonexistent
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, fulfilledId)
        );
        erc721Impl.ownerOf(fulfilledId);

        // Check current counter values
        uint256 beforeCounter = erc721Impl.beforeCounter();
        uint256 afterCounter = erc721Impl.afterCounter();

        // Call fulfillToEVM minting fulfilledId & incrementing before and after counters
        vm.expectEmit();
        emit CrossVMBridgeERC721Fulfillment.FulfilledToEVM(recipient, fulfilledId);

        vm.prank(vmBridge);
        CrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, emptyBytes);

        // Confirm id was fulfilled to recipient
        address ownerOf = erc721Impl.ownerOf(fulfilledId);
        assertEq(recipient, ownerOf);

        // Confirm overridden before & after hooks executed
        uint256 postFulfillmentBeforeCounter = erc721Impl.beforeCounter();
        uint256 postFulfillmentAfterCounter = erc721Impl.afterCounter();
        assertEq(postFulfillmentBeforeCounter, beforeCounter + 1);
        assertEq(postFulfillmentAfterCounter, afterCounter + 1);

        // Ensure call fails without token in escrow
        vm.prank(vmBridge);
        vm.expectRevert(
            abi.encodeWithSelector(CrossVMBridgeERC721Fulfillment.FulfillmentFailedTokenNotEscrowed.selector, fulfilledId, vmBridge)
        );
        CrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, emptyBytes);
    }

    function test_FulfillToEVMFromEscrowSucceeds() public {
        // Ensure fulfilledId is nonexistent
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, fulfilledId)
        );
        erc721Impl.ownerOf(fulfilledId);

        // Check current counter values
        uint256 beforeCounter = erc721Impl.beforeCounter();
        uint256 afterCounter = erc721Impl.afterCounter();

        // Call fulfillToEVM minting fulfilledId & incrementing before and after counters
        vm.expectEmit();
        emit CrossVMBridgeERC721Fulfillment.FulfilledToEVM(recipient, fulfilledId);

        vm.prank(vmBridge);
        CrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, emptyBytes);

        // Confirm id was fulfilled to recipient
        address ownerOf = erc721Impl.ownerOf(fulfilledId);
        assertEq(recipient, ownerOf);

        // Confirm overridden before & after hooks executed
        uint256 postFulfillmentBeforeCounter = erc721Impl.beforeCounter();
        uint256 postFulfillmentAfterCounter = erc721Impl.afterCounter();
        assertEq(postFulfillmentBeforeCounter, beforeCounter + 1);
        assertEq(postFulfillmentAfterCounter, afterCounter + 1);

        // Confirm escrow status
        bool isEscrowed = erc721Impl.isEscrowed(fulfilledId);
        assertFalse(isEscrowed);
        
        // Transfer from recipient to escrow & confirm escrow status
        vm.prank(recipient);
        erc721Impl.safeTransferFrom(recipient, vmBridge, fulfilledId);

        address currentOwner = erc721Impl.ownerOf(fulfilledId);
        isEscrowed = erc721Impl.isEscrowed(fulfilledId);
        assertEq(vmBridge, currentOwner);
        assertTrue(isEscrowed);
 
        // Call fulfillToEVM minting fulfilledId & incrementing before and after counters
        vm.expectEmit();
        emit CrossVMBridgeERC721Fulfillment.FulfilledToEVM(recipient, fulfilledId);

        vm.prank(vmBridge);
        CrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, emptyBytes);

        // Confirm id was fulfilled to recipient
        ownerOf = erc721Impl.ownerOf(fulfilledId);
        assertEq(recipient, ownerOf);

        // Confirm overridden before & after hooks executed
        postFulfillmentBeforeCounter = erc721Impl.beforeCounter();
        postFulfillmentAfterCounter = erc721Impl.afterCounter();
        assertEq(postFulfillmentBeforeCounter, beforeCounter + 2);
        assertEq(postFulfillmentAfterCounter, afterCounter + 2);
    }

    function test_SupportsAllExpectedInterfacesSucceeds() public {
        bytes4 iErc721Id = type(IERC721).interfaceId;
        bytes4 i721FulfillmentId = type(ICrossVMBridgeERC721Fulfillment).interfaceId;
        bytes4 callableId = type(CrossVMBridgeCallable).interfaceId;

        assertTrue(erc721Impl.supportsInterface(iErc721Id));
        assertTrue(erc721Impl.supportsInterface(i721FulfillmentId));
        assertTrue(erc721Impl.supportsInterface(callableId));
    }
}