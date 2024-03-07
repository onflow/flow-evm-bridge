// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IFlowBridgeOptOut is IERC165 {
    function confirmOptOut() external view returns (bool);
}