// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.21;

import "../../../constants/Arbitrum.sol";

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {TokensGenerator} from "../_common/TokensGenerator.sol";
import {ChainlinkV3OracleConfig} from "../../../contracts/chainlinkV3/ChainlinkV3OracleConfig.sol";
import {ChainlinkV3OracleFactory, ChainlinkV3Oracle, IChainlinkV3Oracle} from "../../../contracts/chainlinkV3/ChainlinkV3OracleFactory.sol";
import {ChainlinkV3Configs} from "../_common/ChainlinkV3Configs.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract ChainlinkV3OracleFactoryTest
*/
contract ChainlinkV3OracleFactoryTest is ChainlinkV3Configs {
    uint256 constant TEST_BLOCK = 18026824; // ETH@1817

    ChainlinkV3OracleFactory public immutable ORACLE_FACTORY;

    constructor() TokensGenerator(BlockChain.ETHEREUM) {
        initFork(TEST_BLOCK);

        ORACLE_FACTORY = new ChainlinkV3OracleFactory();
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_ChainlinkV3OracleFactory_verifyConfig
    */
    function test_ChainlinkV3OracleFactory_verifyConfig() public view {
        ORACLE_FACTORY.verifyConfig(_dydxChainlinkV3Config());
        ORACLE_FACTORY.verifyConfig(_spellEthChainlinkV3Config());
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_ChainlinkV3OracleFactory_quote_DYDXinUSDT
    */
    function test_ChainlinkV3OracleFactory_quote_DYDXinUSDT() public {
        ChainlinkV3Oracle oracle = ORACLE_FACTORY.create(_dydxChainlinkV3Config());

        uint256 price = oracle.quote(1e18, address(tokens["DYDX"]));
        emit log_named_decimal_uint("DYDX/USD", price, 6);

        assertEq(price, 2_128486, "DYDX/USD price is ~$2.14");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_ChainlinkV3OracleFactory_quote_SPELLinUSD
    */
    function test_ChainlinkV3OracleFactory_quote_SPELLinUSD() public {
        ChainlinkV3Oracle oracle = ORACLE_FACTORY.create(_spellUsdChainlinkV3Config());

        uint256 gasStart = gasleft();
        uint256 price = oracle.quote(1e18, address(tokens["SPELL"]));
        uint256 gasEnd = gasleft();
        emit log_named_uint("gas used", gasStart - gasEnd);

        emit log_named_decimal_uint("SPELL/USD", price, 6);
        assertEq(price, 403, ", SPELL/USD price is ~$0.000403");
        assertEq(gasStart - gasEnd, 15538, "[ChainlinkV3OracleFactory_quote_SPELLinUSD] optimise gas");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vv --mt test_ChainlinkV3OracleFactory_quote_SPELLinETH
    */
    function test_ChainlinkV3OracleFactory_quote_SPELLinETH() public {
        uint256 gasStart = gasleft();
        ChainlinkV3Oracle oracle = ORACLE_FACTORY.create(_spellEthChainlinkV3Config());
        uint256 gasEnd = gasleft();

        emit log_named_uint("gas", gasStart - gasEnd);
        assertEq(gasStart - gasEnd, 338349, "[ChainlinkV3OracleFactory_quote_SPELLinETH] optimise gas for creation");

        gasStart = gasleft();
        uint256 price = oracle.quote(1e18, address(tokens["SPELL"]));
        gasEnd = gasleft();
        emit log_named_uint("gas used", gasStart - gasEnd);

        emit log_named_decimal_uint("SPELL/ETH", price, 18);
        assertEq(price, 235285547785, ", SPELL/USD price is ~$0.000403 => ETH@1716 => SPELL/ETH ~ 0.000403/1716 => 0.00000023");
        assertEq(gasStart - gasEnd, 27606, "[ChainlinkV3OracleFactory_quote_SPELLinETH] optimise gas");
    }
}
