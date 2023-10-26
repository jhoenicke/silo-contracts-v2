// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc DepositTest
*/
contract GettersTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;


    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_silo_getInfo
    */
    function test_silo_getInfo() public {
        (string memory version, ISiloFactory factory, uint256 siloId) = silo0.getInfo();

        assertEq(version, "2.0.0", "version");
        assertTrue(address(factory) != address(0), "factory not empty");
        assertEq(siloId, 1, "siloId");

    }

    /*
    forge test -vv --ffi --mt test_silo_getLiquidity
    */
    function test_silo_getLiquidity() public {
        assertEq(silo0.getLiquidity(), 0, "no liquidity after deploy 0");
        assertEq(silo1.getLiquidity(), 0, "no liquidity after deploy 1");
    }

    /*
    forge test -vv --ffi --mt test_silo_getMaxLtv
    */
    function test_silo_getMaxLtv() public {
        assertEq(silo0.getMaxLtv(), 0.75e18, "getMaxLtv 0");
        assertEq(silo1.getMaxLtv(), 0.85e18, "getMaxLtv 1");
    }

    /*
    forge test -vv --ffi --mt test_silo_getLt
    */
    function test_silo_getLt() public {
        assertEq(silo0.getLt(), 0.85e18, "LT 0");
        assertEq(silo1.getLt(), 0.95e18, "LT 1");
    }

    /*
    forge test -vv --ffi --mt test_silo_asset
    */
    function test_silo_asset() public {
        assertEq(silo0.asset(), address(0x4c553509592FEb3fc70e11b3ffbCeF3Ff6FcA0F0), "asset 0");
        assertEq(silo1.asset(), address(0xda3464b755344CF98B5c7386A368F2d065066356), "asset 1");
    }

    /*
    forge test -vv --ffi --mt test_silo_getFeesAndFeeReceivers
    */
    function test_silo_getFeesAndFeeReceivers() public {
        (
            address daoFeeReceiver, address deployerFeeReceiver, uint256 daoFee, uint256 deployerFee
        ) = silo0.getFeesAndFeeReceivers();

        assertEq(daoFeeReceiver, address(0x19dD10675e508168B181f7acEc4D6E7eD3cbB737), "daoFeeReceiver");
        assertEq(deployerFeeReceiver, address(0x0000000000000000000000000000000000000480), "deployerFeeReceiver");
        assertEq(daoFee, 0.15e18, "daoFee");
        assertEq(deployerFee, 0.1e18, "deployerFee");

        (daoFeeReceiver, deployerFeeReceiver, daoFee, deployerFee) = silo1.getFeesAndFeeReceivers();

        assertEq(daoFeeReceiver, address(0x19dD10675e508168B181f7acEc4D6E7eD3cbB737), "daoFeeReceiver 1");
        assertEq(deployerFeeReceiver, address(0x0000000000000000000000000000000000000480), "deployerFeeReceiver 1");
        assertEq(daoFee, 0.15e18, "daoFee 1");
        assertEq(deployerFee, 0.1e18, "deployerFee 1");
    }
}