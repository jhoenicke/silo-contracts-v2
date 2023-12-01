// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";

import {GaugeHookReceiverDeploy} from "silo-core/deploy/GaugeHookReceiverDeploy.s.sol";

import {IGaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/interfaces/IGaugeHookReceiver.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

// FOUNDRY_PROFILE=core forge test -vv --ffi --mc GaugeHookReceiverTest
contract GaugeHookReceiverDeployTest is Test {
    // forge test -vv --ffi --mt test_GaugeHookReceiverDeploy_run
    function test_GaugeHookReceiverDeploy_run() public {
        GaugeHookReceiverDeploy deploy = new GaugeHookReceiverDeploy();
        deploy.disableDeploymentsSync();

        IGaugeHookReceiver hookReceiver = deploy.run();
        assertTrue(address(hookReceiver) != address(0), "expect deployed address");

        vm.expectRevert("Initializable: contract is already initialized");
        hookReceiver.initialize(makeAddr("owner"), IShareToken(makeAddr("IShareToken")));
    }
}