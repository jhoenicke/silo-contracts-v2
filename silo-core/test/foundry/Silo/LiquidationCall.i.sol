// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloLiquidation} from "silo-core/contracts/interfaces/ISiloLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

import {SiloFixture} from "../_common/fixtures/SiloFixture.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {MintableToken} from "../_common/MintableToken.sol";


/*
    forge test -vv --mc LiquidationCallTest
*/
contract LiquidationCallTest is SiloLittleHelper, Test {
    address constant BORROWER = address(0x123);

    ISiloConfig siloConfig;

    event LiquidationCall(address indexed liquidator, bool receiveSToken);

    function setUp() public {
        token0 = new MintableToken();
        token1 = new MintableToken();

        SiloFixture siloFixture = new SiloFixture();
        (siloConfig, silo0, silo1,,) = siloFixture.deploy_local(SiloFixture.Override(address(token0), address(token1)));

        __init(vm, token0, token1, silo0, silo1);

        _depositForBorrow(8e18, address(1));

        _deposit(10e18, BORROWER);
        _borrow(7.5e18, BORROWER);

        assertEq(token0.balanceOf(address(this)), 0, "liquidation should have no collateral");
        assertEq(token0.balanceOf(address(silo0)), 10e18, "silo0 has borrower collateral");
        assertEq(token1.balanceOf(address(silo1)), 0.5e18, "silo1 has only 0.5 debt token (8 - 7.5)");
    }

    /*
    forge test -vv --mt test_liquidationCall_UnexpectedCollateralToken
    */
    function test_liquidationCall_UnexpectedCollateralToken() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(ISiloLiquidation.UnexpectedCollateralToken.selector);
        silo1.liquidationCall(address(token1), address(token1), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --mt test_liquidationCall_UnexpectedDebtToken
    */
    function test_liquidationCall_UnexpectedDebtToken() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(ISiloLiquidation.UnexpectedDebtToken.selector);
        silo1.liquidationCall(address(token0), address(token0), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --mt test_liquidationCall_NoDebtToCover_whenZero
    */
    function test_liquidationCall_NoDebtToCover_whenZero() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(ISiloLiquidation.NoDebtToCover.selector);
        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --mt test_liquidationCall_NoDebtToCover_whenUserSolvent
    */
    function test_liquidationCall_NoDebtToCover_whenUserSolvent() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        vm.expectRevert(ISiloLiquidation.NoDebtToCover.selector);
        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --mt test_liquidationCall_self
    */
    function test_liquidationCall_self() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        token1.mint(BORROWER, debtToCover);
        vm.prank(BORROWER);
        token1.approve(address(silo1), debtToCover);

        vm.expectEmit(true, true, true, true);
        emit LiquidationCall(BORROWER, receiveSToken);

        vm.prank(BORROWER);
        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --mt test_liquidationCall_partial
    */
    function test_liquidationCall_partial() public {
        uint256 debtToCover = 1e5;
        bool receiveSToken;
        address liquidator = address(this);

        (
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.ConfigData memory collateralConfig
        ) = siloConfig.getConfigs(address(silo1));

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo1.siloData();

        // move forward with time so we can have interests
        uint256 timeForward = 7 days;
        vm.warp(block.timestamp + timeForward);

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(address(debtConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector, block.timestamp));
        vm.expectCall(address(collateralConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector, block.timestamp));

        token1.mint(liquidator, debtToCover);
        token1.approve(address(silo1), debtToCover);

        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, receiveSToken);

        assertEq(token0.balanceOf(liquidator), 1e5 + 0.05e5, "liquidator should get collateral + 5% fee");
        assertEq(token0.balanceOf(address(silo0)), 10e18 - (1e5 + 0.05e5), "silo collateral should be tranfered to liquidator");
        assertEq(token1.balanceOf(address(silo1)), 0.5e18 + 1e5, "debt token should be repayed");

        assertEq(silo0.getCollateralAssets(), 10e18 - (1e5 + 0.05e5), "total collateral");
        assertEq(silo1.getDebtAssets(), 8e18 + 911884679907104475, "debt token + interest");

        (, uint64 interestRateTimestamp0After) = silo0.siloData();
        (, uint64 interestRateTimestamp1After) = silo1.siloData();

        assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
        assertEq(interestRateTimestamp1 + timeForward, interestRateTimestamp1After, "interestRateTimestamp #1");
    }

    /*
    forge test -vv --mt test_liquidationCall_badDebt_partial
    */
    function test_liquidationCall_badDebt_partial() public {
        uint256 debtToCover = 100e18;
        bool receiveSToken;
        address liquidator = address(this);

        (
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.ConfigData memory collateralConfig
        ) = siloConfig.getConfigs(address(silo1));

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo1.siloData();

        // move forward with time so we can have interests

        uint256 timeForward = 30 days;
        vm.warp(block.timestamp + timeForward);
        // expected debt should grow from 7.5 => ~70

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(address(debtConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector, block.timestamp));
        vm.expectCall(address(collateralConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector, block.timestamp));

        token1.mint(liquidator, debtToCover);
        token1.approve(address(silo1), debtToCover);

        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, receiveSToken);

        assertTrue(silo0.isSolvent(BORROWER), "user is solvent");
        assertTrue(silo1.isSolvent(BORROWER), "user is solvent");

        uint256 interest = 61_643835616429440000;
        uint256 daoAndDeployerFees = interest * (0.15e4 + 0.10e4) / 1e4; // dao fee + deployer fee

        assertEq(token0.balanceOf(liquidator), 10e18, "liquidator should get all borrower collateral, no fee because of bad debt");
        assertEq(token0.balanceOf(address(silo0)), 0, "all silo collateral should be transfer to liquidator");
        assertEq(silo0.getCollateralAssets(), 0, "total collateral");

        assertEq(token1.balanceOf(address(silo1)), 0.5e18 + 7.5e18 + interest, "silo has debt token fully repay, debt deposit + interest");
        assertEq(silo1.getCollateralAssets(), 0.5e18 + 7.5e18 + interest - daoAndDeployerFees, "borrowed token + interest");
        assertEq(token1.balanceOf(liquidator), 100e18 - (7.5e18 + interest), "liquidator did not used all the tokens");

        /*
          _totalCollateral.assets before %   8000000000000000000
          _totalDebt.assets before %         7500000000000000000

          _totalCollateral.assets %         54232876712322080000 (8 + accruedInterest - daoAndDeployerFees)
          _totalDebt.assets %               69143835616429440000 (7.5 + all interest)

          totalFees (daoAndDeployerFees) %  15410958904107360000
          accruedInterest %                 61643835616429440000
        */

        (, uint64 interestRateTimestamp0After) = silo0.siloData();
        (, uint64 interestRateTimestamp1After) = silo1.siloData();

        assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
        assertEq(interestRateTimestamp1 + timeForward, interestRateTimestamp1After, "interestRateTimestamp #1");
    }

    /*
    forge test -vv --mt test_liquidationCall_badDebt_full_withToken
    */
    function test_liquidationCall_badDebt_full_withToken() public {
        bool receiveSToken;
        address liquidator = address(this);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, liquidator, 10e18));

        _liquidationCall_badDebt_full(receiveSToken);

        assertEq(token0.balanceOf(liquidator), 10e18, "liquidator should get all collateral because of full liquidation");
        assertEq(silo0.getCollateralAssets(), 0, "total collateral");
        assertEq(token0.balanceOf(address(silo0)), 0, "silo collateral should be transfer to liquidator");
    }

    /*
    forge test -vv --mt test_liquidationCall_badDebt_full_withSToken
    */
    function test_liquidationCall_badDebt_full_withSToken() public {
        bool receiveSToken = true;
        uint256 collateralSharesToLiquidate = 10e18;
        address liquidator = address(this);

        (, ISiloConfig.ConfigData memory collateralConfig) = siloConfig.getConfigs(address(silo1));

        vm.expectCall(collateralConfig.collateralShareToken, abi.encodeWithSelector(IShareToken.forwardTransfer.selector, BORROWER, liquidator, collateralSharesToLiquidate));

        _liquidationCall_badDebt_full(receiveSToken);

        assertEq(token0.balanceOf(liquidator), 0, "liquidator should not have collateral, because of sToken");
        assertEq(silo0.getCollateralAssets(), 10e18, "silo still has collateral assets, because of sToken");
        assertEq(token0.balanceOf(address(silo0)), 10e18, "silo still has collateral balance, because of sToken");
    }

    function _liquidationCall_badDebt_full(bool _receiveSToken) internal {
        uint256 debtToCover = 100e18;
        address liquidator = address(this);

        // move forward with time so we can have interests

        uint256 timeForward = 50 days;
        vm.warp(block.timestamp + timeForward);

        uint256 maxRepay = silo1.maxRepay(BORROWER);

        token1.mint(liquidator, debtToCover);
        token1.approve(address(silo1), debtToCover);

        vm.expectRevert("ERC20: insufficient allowance"); // because of dust, debt is 110 and we want to repay 100
        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, _receiveSToken);

        token1.mint(liquidator, maxRepay - debtToCover);
        token1.increaseAllowance(address(silo1), maxRepay - debtToCover);

        vm.expectCall(address(token1), abi.encodeWithSelector(IERC20.transferFrom.selector, liquidator, address(silo1), maxRepay));

        silo1.liquidationCall(address(token0), address(token1), BORROWER, maxRepay, _receiveSToken);

        assertEq(token1.balanceOf(address(silo1)), maxRepay + 0.5e18, "silo has debt token == to cover + original 0.5");

        assertEq(silo1.getDebtAssets(), 0, "debt is repay");
        assertGt(silo1.getCollateralAssets(), 8e18, "collateral ready to borrow (with interests)");
    }
}