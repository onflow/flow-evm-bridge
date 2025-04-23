pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Wrapper} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Wrapper.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {FlowEVMBridgedERC721} from "../src/templates/FlowEVMBridgedERC721.sol";
import {ICrossVM} from "../src/interfaces/ICrossVM.sol";
import {ICrossVMBridgeCallable} from "../src/interfaces/ICrossVMBridgeCallable.sol";
import {ICrossVMBridgeERC721Fulfillment} from "../src/interfaces/ICrossVMBridgeERC721Fulfillment.sol";
import {ICrossVMBridgeERC721Fulfillment} from "../src/interfaces/ICrossVMBridgeERC721Fulfillment.sol";
import {CadenceNativeERC721WithWrapper} from "../src/example-assets/cross-vm-nfts/CadenceNativeERC721WithWrapper.sol";

contract CrossVMBridgeERC721FulfillmentTest is Test {
    FlowEVMBridgedERC721 internal underlyingERC721Impl; // the bridged ERC721 token being wrapped
    CadenceNativeERC721WithWrapper internal erc721Impl;

    string name;
    string symbol;
    string cadenceAddress;
    string cadenceIdentifier;
    address vmBridge;

    address recipient;

    uint256 fulfilledId;
    string expectedTokenURI = 'data:application/json;utf8,{"name": "name", "symbol": "symbol"}';
    bytes bridgedBytes;

    function setUp() public {
        name = "name";
        symbol = "symbol";
        cadenceAddress = "0xf8d6e0586b0a20c7"; // example Cadence contract address
        cadenceIdentifier = "A.f8d6e0586b0a20c7.ExampleCadenceNativeNFT.NFT"; // example Cadence NFT Type identifier

        vmBridge = address(100);
        recipient = address(101);

        fulfilledId = 42;
        bridgedBytes = abi.encode(expectedTokenURI);

        underlyingERC721Impl = new FlowEVMBridgedERC721(vmBridge, name, symbol, cadenceAddress, cadenceIdentifier, "");
        erc721Impl = new CadenceNativeERC721WithWrapper(name, symbol, cadenceAddress, cadenceIdentifier, address(underlyingERC721Impl), vmBridge);
    }

    function test_VMBridgeAddressMatches() public view {
        address actualVMBridge = erc721Impl.vmBridgeAddress();
        assertEq(vmBridge, actualVMBridge);
    }

    function test_ICrossVMValuesMatch() public view {
        string memory actualCadenceAddress = ICrossVM(erc721Impl).getCadenceAddress();
        string memory actualCadenceIdentifier = ICrossVM(erc721Impl).getCadenceIdentifier();
        assertEq(cadenceAddress, actualCadenceAddress);
        assertEq(cadenceIdentifier, actualCadenceIdentifier);
    }

    function test_WrapUnderlyingSucceeds() public {
        vm.prank(vmBridge);
        underlyingERC721Impl.safeMint(recipient, fulfilledId, "");

        // Ensure recipient is owner
        bool received = recipient == underlyingERC721Impl.ownerOf(fulfilledId);
        assertTrue(received);

        // Construct depositFor id array
        uint256[] memory ids = new uint256[](1);
        ids[0] = fulfilledId;

        // Approve then wrap the underlying token
        vm.prank(recipient);
        underlyingERC721Impl.approve(address(erc721Impl), fulfilledId);

        vm.prank(recipient);
        bool wrappedReceived = erc721Impl.depositFor(recipient, ids);
        bool underlyingIsWrapped = address(erc721Impl) == underlyingERC721Impl.ownerOf(fulfilledId);
        assertTrue(wrappedReceived);
        assertTrue(underlyingIsWrapped);
    }

    function test_UnwrapUnderlyingSucceeds() public {
        vm.prank(vmBridge);
        underlyingERC721Impl.safeMint(recipient, fulfilledId, "");

        // Construct depositFor id array
        uint256[] memory ids = new uint256[](1);
        ids[0] = fulfilledId;

        // Approve then wrap the underlying token
        vm.prank(recipient);
        underlyingERC721Impl.approve(address(erc721Impl), fulfilledId);
        vm.prank(recipient);
        bool wrapped = erc721Impl.depositFor(recipient, ids);

        // Unwrap the token
        vm.prank(recipient);
        bool unwrapped = erc721Impl.withdrawTo(recipient, ids);
        bool underlyingIsUnwrapped = address(recipient) == underlyingERC721Impl.ownerOf(fulfilledId);
        assertTrue(unwrapped);
        assertTrue(underlyingIsUnwrapped);

        // Ensure the wrapped token was burned
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, fulfilledId)
        );
        erc721Impl.ownerOf(fulfilledId);
    }

    function test_FulfillToEVMAsUnauthorizedFails() public {
        vm.prank(recipient);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossVMBridgeCallable.CrossVMBridgeCallableUnauthorizedAccount.selector, recipient)
        );
        ICrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, bridgedBytes);
    }

    function test_FulfillToEVMMintSucceeds() public {
        bool exists = erc721Impl.exists(fulfilledId);
        assertFalse(exists);

        // Ensure fulfilledId is nonexistent
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, fulfilledId)
        );
        erc721Impl.ownerOf(fulfilledId);

        // Call fulfillToEVM minting fulfilledId & incrementing before and after counters
        vm.expectEmit();
        emit ICrossVMBridgeERC721Fulfillment.FulfilledToEVM(recipient, fulfilledId);

        vm.prank(vmBridge);
        ICrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, bridgedBytes);

        // Confirm id was fulfilled to recipient
        address ownerOf = erc721Impl.ownerOf(fulfilledId);
        exists = erc721Impl.exists(fulfilledId);
        assertEq(recipient, ownerOf);
        assertTrue(exists);

        // Check tokenURI assignment from provided data
        string memory actualTokenURI = erc721Impl.tokenURI(fulfilledId);
        assertEq(expectedTokenURI, actualTokenURI);
    }

    function test_FulfillToEVMUnescrowedFails() public {
        // Ensure fulfilledId is nonexistent
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, fulfilledId)
        );
        erc721Impl.ownerOf(fulfilledId);

        // Call fulfillToEVM minting fulfilledId & incrementing before and after counters
        vm.expectEmit();
        emit ICrossVMBridgeERC721Fulfillment.FulfilledToEVM(recipient, fulfilledId);

        vm.prank(vmBridge);
        ICrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, bridgedBytes);

        // Confirm id was fulfilled to recipient
        address ownerOf = erc721Impl.ownerOf(fulfilledId);
        assertEq(recipient, ownerOf);

        // Ensure call fails without token in escrow
        vm.prank(vmBridge);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossVMBridgeERC721Fulfillment.FulfillmentFailedTokenNotEscrowed.selector, fulfilledId, vmBridge)
        );
        ICrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, bridgedBytes);
    }

    function test_FulfillToEVMFromEscrowSucceeds() public {
        // Ensure fulfilledId is nonexistent
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, fulfilledId)
        );
        erc721Impl.ownerOf(fulfilledId);

        // Call fulfillToEVM minting fulfilledId & incrementing before and after counters
        vm.expectEmit();
        emit ICrossVMBridgeERC721Fulfillment.FulfilledToEVM(recipient, fulfilledId);

        vm.prank(vmBridge);
        ICrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, bridgedBytes);

        // Confirm id was fulfilled to recipient
        address ownerOf = erc721Impl.ownerOf(fulfilledId);
        assertEq(recipient, ownerOf);

        // Confirm escrow status
        bool isEscrowed = ICrossVMBridgeERC721Fulfillment(erc721Impl).isEscrowed(fulfilledId);
        assertFalse(isEscrowed);
        
        // Transfer from recipient to escrow & confirm escrow status
        vm.prank(recipient);
        erc721Impl.safeTransferFrom(recipient, vmBridge, fulfilledId);

        address currentOwner = erc721Impl.ownerOf(fulfilledId);
        isEscrowed = ICrossVMBridgeERC721Fulfillment(erc721Impl).isEscrowed(fulfilledId);
        assertEq(vmBridge, currentOwner);
        assertTrue(isEscrowed);
 
        // Call fulfillToEVM minting fulfilledId & incrementing before and after counters
        vm.expectEmit();
        emit ICrossVMBridgeERC721Fulfillment.FulfilledToEVM(recipient, fulfilledId);

        vm.prank(vmBridge);
        ICrossVMBridgeERC721Fulfillment(erc721Impl).fulfillToEVM(recipient, fulfilledId, bridgedBytes);

        // Confirm id was fulfilled to recipient
        ownerOf = erc721Impl.ownerOf(fulfilledId);
        assertEq(recipient, ownerOf);
    }

    function test_SupportsAllExpectedInterfacesSucceeds() public view {
        assertTrue(erc721Impl.supportsInterface(type(IERC721).interfaceId));
        assertTrue(erc721Impl.supportsInterface(type(ICrossVMBridgeERC721Fulfillment).interfaceId));
        assertTrue(erc721Impl.supportsInterface(type(ICrossVMBridgeCallable).interfaceId));
    }
}