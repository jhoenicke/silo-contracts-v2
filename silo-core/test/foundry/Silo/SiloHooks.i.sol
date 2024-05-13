// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {HookReceiverMock} from "silo-core/test/foundry/_mocks/HookReceiverMock.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ContractThatAcceptsETH} from "silo-core/test/foundry/_mocks/ContractThatAcceptsETH.sol";

import {SiloFixture, SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mc SiloHooksTest
contract SiloHooksTest is SiloLittleHelper, Test {
    uint24 constant HOOKS_BEFORE = 1;
    uint24 constant HOOKS_AFTER = 2;

    SiloFixture internal _siloFixture;
    HookReceiverMock internal _hookReceiverMock;
    ISiloConfig internal _siloConfig;

    address internal _thridParty = makeAddr("ThirdParty");
    address internal _hookReceiverAddr;

    address internal timelock = makeAddr("Timelock");
    address internal feeDistributor = makeAddr("FeeDistributor");

    function setUp() public {
        // Mock addresses that we need for the `SiloFactoryDeploy` script
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, timelock);
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, feeDistributor);

        _siloFixture = new SiloFixture();
        SiloConfigOverride memory configOverride;

        _hookReceiverMock = new HookReceiverMock(address(0));
        _hookReceiverMock.hookReceiverConfigMock(HOOKS_BEFORE, HOOKS_AFTER);

        _hookReceiverAddr = _hookReceiverMock.ADDRESS();

        configOverride.token0 = makeAddr("token0");
        configOverride.token1 = makeAddr("token1");
        configOverride.hookReceiver = _hookReceiverAddr;
        configOverride.configName = SiloConfigsNames.LOCAL_DEPLOYER;

        (_siloConfig, silo0, silo1,,,) = _siloFixture.deploy_local(configOverride);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testHooksInitializationAfterDeployment
    */
    function testHooksInitializationAfterDeployment() public {
        (,uint24 silo0HookesBefore, uint24 silo0HookesAfter,) = silo0.sharedStorage();

        assertEq(silo0HookesBefore, HOOKS_BEFORE, "hooksBefore is not initialized");
        assertEq(silo0HookesAfter, HOOKS_AFTER, "hooksAfter is not initialized");

        (,uint24 silo1HookesBefore, uint24 silo1HookesAfter,) = silo1.sharedStorage();

        assertEq(silo1HookesBefore, HOOKS_BEFORE, "hooksBefore is not initialized");
        assertEq(silo1HookesAfter, HOOKS_AFTER, "hooksAfter is not initialized");
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testHooksUpdate
    function testHooksUpdate() public {
        uint24 newHooksBefore = 3;
        uint24 newHooksAfter = 4;

        _hookReceiverMock.hookReceiverConfigMock(newHooksBefore, newHooksAfter);

        silo0.updateHooks();

        (,uint24 silo0HookesBefore, uint24 silo0HookesAfter,) = silo0.sharedStorage();

        assertEq(silo0HookesBefore, newHooksBefore, "hooksBefore is not updated");
        assertEq(silo0HookesAfter, newHooksAfter, "hooksAfter is not updated");

        silo1.updateHooks();

        (,uint24 silo1HookesBefore, uint24 silo1HookesAfter,) = silo1.sharedStorage();

        assertEq(silo1HookesBefore, newHooksBefore, "hooksBefore is not updated");
        assertEq(silo1HookesAfter, newHooksAfter, "hooksAfter is not updated");
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testCallOnBehalfOfSilo
    function testCallOnBehalfOfSilo() public {
        (address protectedShareToken,,) = _siloConfig.getShareTokens(address(silo0));

        uint256 tokensToMint = 100;
        bytes memory data = abi.encodeWithSelector(IShareToken.mint.selector, _thridParty, _thridParty, tokensToMint);

        uint256 amountOfEth = 0;

        vm.expectRevert(ISilo.OnlyHookReceiver.selector);
        silo0.callOnBehalfOfSilo(protectedShareToken, amountOfEth, data);

        assertEq(IERC20(protectedShareToken).balanceOf(_thridParty), 0);

        vm.prank(_hookReceiverAddr);
        silo0.callOnBehalfOfSilo(protectedShareToken, amountOfEth, data);

        assertEq(IERC20(protectedShareToken).balanceOf(_thridParty), tokensToMint);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testCallOnBehalfOfSiloWithETH
    function testCallOnBehalfOfSiloWithETH() public {
        address target = address(new ContractThatAcceptsETH());
        bytes memory data = abi.encodeWithSelector(ContractThatAcceptsETH.anyFunction.selector);

        assertEq(target.balance, 0, "Expect to have no balance");

        uint256 amoutToSend = 1 ether;

        vm.deal(_hookReceiverAddr, amoutToSend);
        vm.prank(_hookReceiverAddr);
        silo0.callOnBehalfOfSilo{value: amoutToSend}(target, amoutToSend, data);

        assertEq(target.balance, amoutToSend, "Expect to have non zero balance");
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testCallOnBehalfOfSiloWithETHleftover
    function testCallOnBehalfOfSiloWithETHleftover() public {
        address target = address(new ContractThatAcceptsETH());
        bytes memory data = abi.encodeWithSelector(ContractThatAcceptsETH.anyFunctionThatSendEthBack.selector);

        assertEq(target.balance, 0, "Expect to have no balance");

        uint256 amoutToSend = 1 ether;

        vm.deal(_hookReceiverAddr, amoutToSend);
        vm.prank(_hookReceiverAddr);
        silo0.callOnBehalfOfSilo{value: amoutToSend}(target, amoutToSend, data);

        assertEq(address(silo0).balance, amoutToSend, "Expect to have non zero balance");

        // transfer ether leftover in a separate transaction
        assertEq(_hookReceiverAddr.balance, 0, "Expect to have no balance on a hook receiver");

        bytes memory emptyPayload;

        vm.prank(_hookReceiverAddr);
        silo0.callOnBehalfOfSilo{value: 0}(_hookReceiverAddr, amoutToSend, emptyPayload);

        assertEq(_hookReceiverAddr.balance, amoutToSend, "Expect to have non zero balance on a hook receiver");
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testHooksMissconfiguration
    function testHooksMissconfiguration() public {
        vm.expectRevert(ISiloDeployer.HookReceiverMissconfigured.selector);
        _siloFixture.deploy_local(SiloConfigsNames.LOCAL_HOOKS_MISSCONFIGURATION);
    }
}