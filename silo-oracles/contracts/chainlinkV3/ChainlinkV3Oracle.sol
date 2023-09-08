// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Initializable} from  "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {OracleNormalization} from "../lib/OracleNormalization.sol";
import {ChainlinkV3OracleConfig} from "./ChainlinkV3OracleConfig.sol";
import {IChainlinkV3Oracle} from "../interfaces/IChainlinkV3Oracle.sol";

contract ChainlinkV3Oracle is IChainlinkV3Oracle, ISiloOracle, Initializable {
    ChainlinkV3OracleConfig public oracleConfig;

    /// @notice validation of config is checked in factory, therefore you should not deploy and initialize directly
    /// use factory always.
    function initialize(ChainlinkV3OracleConfig _configAddress) external virtual initializer {
        oracleConfig = _configAddress;
        emit ChainlinkV3ConfigDeployed(_configAddress);
    }

    /// @inheritdoc ISiloOracle
    function quote(uint256 _baseAmount, address _baseToken) external virtual returns (uint256 quoteAmount) {
        return _quote(_baseAmount, _baseToken);
    }

    /// @dev Returns price directly from aggregator, this method is mostly for debug purposes
    function getAggregatorPrice(bool _primary) external view virtual returns (bool success, uint256 price) {
        IChainlinkV3Oracle.ChainlinkV3Config memory config = oracleConfig.getConfig();
        return _primary
            ? _getAggregatorPrice(config.primaryAggregator, config.primaryHeartbeat)
            : _getAggregatorPrice(config.secondaryAggregator, config.secondaryHeartbeat);
    }

    /// @inheritdoc ISiloOracle
    function quoteView(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        return _quote(_baseAmount, _baseToken);
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        IChainlinkV3Oracle.ChainlinkV3Config memory config = oracleConfig.getConfig();
        return address(config.quoteToken);
    }

    function _quote(uint256 _baseAmount, address _baseToken) internal view virtual returns (uint256 quoteAmount) {
        ChainlinkV3Config memory config = oracleConfig.getConfig();

        if (_baseToken != address(config.baseToken)) revert AssetNotSupported();
        if (_baseAmount > type(uint128).max) revert BaseAmountOverflow();

        (bool success, uint256 price) = _getAggregatorPrice(config.primaryAggregator, config.primaryHeartbeat);
        if (!success) revert InvalidPrice();

        if (!config.convertToQuote) {
            return OracleNormalization.normalizePrice(
                _baseAmount, price, config.normalizationDivider, config.normalizationMultiplier
            );
        }

        (
            bool secondSuccess,
            uint256 secondPrice
        ) = _getAggregatorPrice(config.secondaryAggregator, config.primaryHeartbeat);

        if (!secondSuccess) revert InvalidSecondPrice();

        return OracleNormalization.normalizePrices(
            _baseAmount,
            price,
            secondPrice,
            config.normalizationDivider,
            config.normalizationMultiplier
        );
    }

    function _getAggregatorPrice(AggregatorV3Interface _aggregator, uint256 _heartbeat)
        internal
        view
        virtual
        returns (bool success, uint256 price)
    {
        (
            /*uint80 roundID*/,
            int256 aggregatorPrice,
            /*uint256 startedAt*/,
            uint256 priceTimestamp,
            /*uint80 answeredInRound*/
        ) = _aggregator.latestRoundData();

        // price must be updated at least once every _heartbeat, otherwise something is wrong
        uint256 oldestAcceptedPriceTimestamp;
        // block.timestamp is more than HEARTBEAT, so we can not underflow
        unchecked { oldestAcceptedPriceTimestamp = block.timestamp - _heartbeat; }

        if (aggregatorPrice > 0 && priceTimestamp > oldestAcceptedPriceTimestamp) {
            return (true, uint256(aggregatorPrice));
        }

        return (false, 0);
    }
}