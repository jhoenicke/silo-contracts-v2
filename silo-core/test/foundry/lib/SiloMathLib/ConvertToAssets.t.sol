// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {StringsUpgradeable as Strings} from "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";

import {SiloMathLib, ISilo, MathUpgradeable} from "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc ConvertToAssetsTest
contract ConvertToAssetsTest is Test {
    struct TestCase {
        uint256 shares;
        uint256 totalAssets;
        uint256 totalShares;
        MathUpgradeable.Rounding rounding;
        ISilo.AssetType assetType;
        uint256 result;
    }

    uint256 public numberOfTestCases = 20;

    mapping(uint256 => TestCase) public cases;

    function setUp() public {
        cases[0] = TestCase({
            shares: 0,
            totalAssets: 0,
            totalShares: 0,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Collateral,
            result: 0
        });

        cases[1] = TestCase({
            shares: 10,
            totalAssets: 0,
            totalShares: 0,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Collateral,
            result: 10
        });

        cases[2] = TestCase({
            shares: 333,
            totalAssets: 1000,
            totalShares: 999,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Collateral,
            result: 333
        });

        cases[3] = TestCase({
            shares: 333,
            totalAssets: 1000,
            totalShares: 999,
            rounding: MathUpgradeable.Rounding.Up,
            assetType: ISilo.AssetType.Collateral,
            result: 334
        });

        cases[4] = TestCase({
            shares: 333,
            totalAssets: 1000,
            totalShares: 1000,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Collateral,
            result: 333
        });

        cases[5] = TestCase({
            shares: 333,
            totalAssets: 1000,
            totalShares: 1000,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Collateral,
            result: 333
        });

        cases[6] = TestCase({
            shares: 1,
            totalAssets: 1000,
            totalShares: 1,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Collateral,
            result: 500
        });

        cases[7] = TestCase({
            shares: 1,
            totalAssets: 1000,
            totalShares: 1,
            rounding: MathUpgradeable.Rounding.Up,
            assetType: ISilo.AssetType.Collateral,
            result: 501
        });

        cases[8] = TestCase({
            shares: 1,
            totalAssets: 1000,
            totalShares: 10,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Collateral,
            result: 91
        });

        cases[9] = TestCase({
            shares: 0,
            totalAssets: 0,
            totalShares: 0,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Debt,
            result: 0
        });

        cases[10] = TestCase({
            shares: 10,
            totalAssets: 0,
            totalShares: 0,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Debt,
            result: 10
        });

        cases[11] = TestCase({
            shares: 333,
            totalAssets: 1000,
            totalShares: 999,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Debt,
            result: 333
        });

        cases[12] = TestCase({
            shares: 333,
            totalAssets: 1000,
            totalShares: 999,
            rounding: MathUpgradeable.Rounding.Up,
            assetType: ISilo.AssetType.Debt,
            result: 334
        });

        cases[13] = TestCase({
            shares: 333,
            totalAssets: 1000,
            totalShares: 1000,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Debt,
            result: 333
        });

        cases[14] = TestCase({
            shares: 333,
            totalAssets: 1000,
            totalShares: 1000,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Debt,
            result: 333
        });

        cases[15] = TestCase({
            shares: 1,
            totalAssets: 1000,
            totalShares: 1,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Debt,
            result: 1000
        });

        cases[16] = TestCase({
            shares: 1,
            totalAssets: 1000,
            totalShares: 1,
            rounding: MathUpgradeable.Rounding.Up,
            assetType: ISilo.AssetType.Debt,
            result: 1000
        });

        cases[17] = TestCase({
            shares: 1,
            totalAssets: 1000,
            totalShares: 10,
            rounding: MathUpgradeable.Rounding.Down,
            assetType: ISilo.AssetType.Debt,
            result: 100
        });

        cases[18] = TestCase({
            shares: 1,
            totalAssets: 1000,
            totalShares: 10,
            rounding: MathUpgradeable.Rounding.Up,
            assetType: ISilo.AssetType.Debt,
            result: 100
        });
    }

    /*
    forge test -vv --mt test_convertToAssets
    */
    function test_convertToAssets() public {
        for (uint256 index = 0; index < numberOfTestCases; index++) {
            assertEq(
                SiloMathLib.convertToAssets(
                    cases[index].shares,
                    cases[index].totalAssets,
                    cases[index].totalShares,
                    cases[index].rounding,
                    cases[index].assetType
                ),
                cases[index].result,
                string.concat("TestCase: ", Strings.toString(index))
            );
        }
    }
}