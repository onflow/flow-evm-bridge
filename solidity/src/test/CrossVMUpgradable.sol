// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ICrossVM} from "../interfaces/ICrossVM.sol";

abstract contract CrossVMUpgradable is Initializable, ICrossVM {

    struct CadencePointerStorage {
        string _cadenceAddress;
        string _cadenceIdentifier;
    }

    function getCadenceAddress() public virtual view returns (string memory) {
        CadencePointerStorage storage $ = _getCadencePointerStorage();
        return $._cadenceAddress;
    }

    function getCadenceIdentifier() public virtual view returns (string memory) {
        CadencePointerStorage storage $ = _getCadencePointerStorage();
        return $._cadenceIdentifier;
    }

    // keccak256(abi.encode(uint256(keccak256("onflow.storage.CrossVMUpgradable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CadencePointerStorageLocation = 0x1f0678a11c0e639afa873a4f85d9812e14ee48821237e3f2af87ee972c7cc500;

    function _getCadencePointerStorage() private pure returns (CadencePointerStorage storage $) {
        assembly {
            $.slot := CadencePointerStorageLocation
        }
    }

    function __CrossVMUpgradable_init(string memory cadenceAddress_, string memory cadenceIdentifier_) internal onlyInitializing {
        __CrossVMUpgradable_init_unchained(cadenceAddress_, cadenceIdentifier_);
    }

    function __CrossVMUpgradable_init_unchained(string memory cadenceAddress_, string memory cadenceIdentifier_) internal onlyInitializing {
        CadencePointerStorage storage $ = _getCadencePointerStorage();
        $._cadenceAddress = cadenceAddress_;
        $._cadenceIdentifier = cadenceIdentifier_;
    }
}
