// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {TestStateLib} from "../../TestState.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";

contract ShareTokenReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
        
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "shareToken()";
    }

    function _ensureItWillNotRevert() internal view {
        address hookReceiver = TestStateLib.hookReceiver();
        IGaugeHookReceiver(hookReceiver).shareToken();
    }
}
