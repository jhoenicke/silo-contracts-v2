// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test --ffi -vv--mc WithdrawAllowanceTest
*/
contract WithdrawAllowanceTest is SiloLittleHelper, Test {
    uint256 internal constant ASSETS = 1e18;

    address immutable DEPOSITOR;
    address immutable RECEIVER;

    ISiloConfig siloConfig;

    constructor() {
        DEPOSITOR = makeAddr("Depositor");
        RECEIVER = makeAddr("Other");
    }

    function setUp() public {
        token0 = new MintableToken();
        token1 = new MintableToken();

        SiloFixture siloFixture = new SiloFixture();
        (siloConfig, silo0, silo1,,) = siloFixture.deploy_local(SiloFixture.Override(address(token0), address(token1)));

        __init(vm, token0, token1, silo0, silo1);
    }

    /*
    forge test --ffi -vv --mt test_withdraw_collateralWithoutAllowance
    */
    function test_withdraw_collateralWithoutAllowance() public {
        _deposit(ASSETS, DEPOSITOR);

        vm.expectRevert("ERC20: insufficient allowance");
        silo0.withdraw(ASSETS, RECEIVER, DEPOSITOR);
    }

    /*
    forge test --ffi -vv --mt test_withdraw_collateralWithAllowance
    */
    function test_withdraw_collateralWithAllowance() public {
        _withdraw_WithAllowance(ISilo.AssetType.Collateral);
    }

    function test_withdraw_protectedWithAllowance() public {
        _withdraw_WithAllowance(ISilo.AssetType.Protected);
    }

    function _withdraw_WithAllowance(ISilo.AssetType _type) internal {
        _deposit(ASSETS, DEPOSITOR, _type);

        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(silo0));

        address shareToken = _type == ISilo.AssetType.Collateral ? collateralShareToken : protectedShareToken;
        vm.prank(DEPOSITOR);
        IShareToken(shareToken).approve(address(this), ASSETS / 2);

        assertEq(token0.balanceOf(RECEIVER), 0, "no balance before");

        silo0.withdraw(ASSETS / 2, RECEIVER, DEPOSITOR,  _type);

        assertEq(token0.balanceOf(RECEIVER), ASSETS / 2, "receiver got tokens");
        assertEq(IShareToken(shareToken).allowance(DEPOSITOR, address(this)), 0, "allowance used");

        vm.expectRevert("ERC20: insufficient allowance");
        silo0.withdraw(1, RECEIVER, DEPOSITOR, _type);

        _withdraw(ASSETS / 2, DEPOSITOR, _type);
        assertEq(token0.balanceOf(DEPOSITOR), ASSETS / 2, "depositor got the rest");
    }
}