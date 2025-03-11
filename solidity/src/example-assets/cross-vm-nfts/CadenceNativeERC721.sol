pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {CrossVMBridgeERC721Fulfillment} from "../../interfaces/CrossVMBridgeERC721Fulfillment.sol";
import {ICrossVM} from "../../interfaces/ICrossVM.sol";

/**
 * @title CadenceNativeERC721
 * @dev This contract is a minimal ERC721 implementation demonstrating the use of the
 * CrossVMBridgeERC721Fulfillment base contract. Such ERC721 contracts are intended for use in
 * cross-VM NFT implementations where projects deploy both a Cadence & Solidity definition with
 * movement of individual NFTs facilitated by Flow's canonical VM bridge.
 * In such cases, NFTs must be distributed in either Cadence or EVM - this is termed the NFT's
 * "native" VM. When moving the NFT into the non-native VM, the bridge implements a mint/escrow
 * pattern, minting if the NFT does not exist and unlocking from escrow if it does.
 * The contract below demonstrates the Solidity implementation for a Cadence-native NFT. By
 * implementing CrossVMBridgeERC721Fulfillment and correctly naming the vmBridgeAddress as the
 * bridge's CadenceOwnedAccount EVM address, this ERC721 enables the bridge to execute the
 * mint/escrow needed to fulfill bridge requests.
 *
 * For more information on cross-VM NFTs, see Flow's developer documentation as well as
 * FLIP-318: https://github.com/onflow/flips/issues/318
 */
contract CadenceNativeERC721 is ICrossVM, ERC721URIStorage, CrossVMBridgeERC721Fulfillment {
    
    // included to test before fulfillment hook
    uint256 public beforeCounter;

    // ICrossVM fields
    string private _cadenceAddress;
    string private _cadenceIdentifier;
    
    constructor(
        string memory name_,
        string memory symbol_,
        string memory cadenceAddress_,
        string memory cadenceIdentifier_,
        address vmBridgeAddress_
    ) CrossVMBridgeERC721Fulfillment(vmBridgeAddress_) ERC721(name_, symbol_) {
        _cadenceAddress = cadenceAddress_;
        _cadenceIdentifier = cadenceIdentifier_;
    }

    function getCadenceAddress() external view returns (string memory) {
        return _cadenceAddress;
    }

    function getCadenceIdentifier() external view returns (string memory) {
        return _cadenceIdentifier;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage, CrossVMBridgeERC721Fulfillment) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    function tokenURI(uint256 id) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(id);
    }

    /**
     * @dev This hook executes before the fulfillment into EVM executes. It's overridden here as
     * a simple demonstration and for testing; however, you might include your own validation or
     * pre-processing.
     * 
     * @param _to address of the pending token recipient
     * @param _id the id of the token to be moved into EVM from Cadence
     * @param _data any encoded metadata passed by the corresponding Cadence NFT at the time of
     *      bridging into EVM
     */
    function _beforeFulfillment(address _to, uint256 _id, bytes memory _data) internal override {
        beforeCounter += 1;
    }

    /**
     * @dev This hook executes after the fulfillment into EVM executes. It's overridden here as
     * a simple demonstration and for testing; however, you might include your own validation or
     * post-processing. For instance, you may decode the bytes passed by the VM bridge at the
     * time of bridging into EVM and update the token's metadata. Since you presumably control the
     * corresponding Cadence implementation, what is passed to your at fulfillment is in your
     * control by having your Cadence NFT resolve the `EVMBytesMetadata` view.
     * 
     * @param _to address of the pending token recipient
     * @param _id the id of the token to be moved into EVM from Cadence
     * @param _data any encoded metadata passed by the corresponding Cadence NFT at the time of
     *      bridging into EVM
     */
    function _afterFulfillment(address _to, uint256 _id, bytes memory _data) internal override {
        string memory decodedURI = abi.decode(_data, (string));
        _setTokenURI(_id, decodedURI);
    }
}