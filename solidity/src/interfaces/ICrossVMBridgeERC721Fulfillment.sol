pragma solidity 0.8.24;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ICrossVMBridgeERC721Fulfillment is IERC165 {

    // Encountered when attempting to fulfill a token that has been previously minted and is not
    // escrowed in EVM under the VM bridge
    error FulfillmentFailedTokenNotEscrowed(uint256 id, address escrowAddress);

    // Emitted when an NFT is moved from Cadence into EVM
    event FulfilledToEVM(address indexed recipient, uint256 indexed tokenId);

    function fulfillToEVM(address to, uint256 id, bytes memory data) external;
}