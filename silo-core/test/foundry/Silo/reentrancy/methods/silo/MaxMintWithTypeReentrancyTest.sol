// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract MaxMintWithTypeReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "maxMint(address,uint8)";
    }

    function _ensureItWillNotRevert() internal {
        address anyAddr = makeAddr("Any address");

        TestStateLib.silo0().maxMint(anyAddr, ISilo.CollateralType.Collateral);
        TestStateLib.silo1().maxMint(anyAddr, ISilo.CollateralType.Collateral);

        TestStateLib.silo0().maxMint(anyAddr, ISilo.CollateralType.Protected);
        TestStateLib.silo1().maxMint(anyAddr, ISilo.CollateralType.Protected);
    }
}