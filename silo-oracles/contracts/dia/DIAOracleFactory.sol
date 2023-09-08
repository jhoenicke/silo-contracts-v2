// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {OracleFactory} from "../_common/OracleFactory.sol";
import {DIAOracle, IDIAOracle} from "../dia/DIAOracle.sol";
import {DIAOracleConfig} from "../dia/DIAOracleConfig.sol";
import {OracleNormalization} from "../lib/OracleNormalization.sol";

contract DIAOracleFactory is OracleFactory {
    /// @dev decimals in DIA oracle
    uint256 public constant DIA_DECIMALS = 8;

    constructor() OracleFactory(address(new DIAOracle())) {
        // noting to set
    }

    function create(IDIAOracle.DIADeploymentConfig calldata _config)
        external
        virtual
        returns (DIAOracle oracle)
    {
        bytes32 id = hashConfig(_config);
        DIAOracleConfig oracleConfig = DIAOracleConfig(getConfigAddress[id]);

        if (address(oracleConfig) != address(0)) {
            // config already exists, so oracle exists as well
            return DIAOracle(getOracleAddress[address(oracleConfig)]);
        }

        verifyConfig(_config);

        bool convertToQuote = bytes(_config.secondaryKey).length != 0;

        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(
            _config.baseToken, _config.quoteToken, DIA_DECIMALS, convertToQuote ? DIA_DECIMALS : 0
        );

        oracleConfig = new DIAOracleConfig(_config, divider, multiplier);

        oracle = DIAOracle(ClonesUpgradeable.clone(ORACLE_IMPLEMENTATION));

        _saveOracle(address(oracle), address(oracleConfig), id);

        oracle.initialize(oracleConfig, _config.primaryKey, _config.secondaryKey);
    }

    function hashConfig(IDIAOracle.DIADeploymentConfig memory _config)
        public
        virtual
        view
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_config));
    }

    function verifyConfig(IDIAOracle.DIADeploymentConfig calldata _config) public view virtual {
        if (address(_config.diaOracle) == address(0)) revert IDIAOracle.AddressZero();
        if (address(_config.quoteToken) == address(0)) revert IDIAOracle.AddressZero();
        if (address(_config.baseToken) == address(0)) revert IDIAOracle.AddressZero();
        if (address(_config.quoteToken) == address(_config.baseToken)) revert IDIAOracle.TokensAreTheSame();
        if (bytes(_config.primaryKey).length == 0) revert IDIAOracle.EmptyPrimaryKey();

        // heartbeat restrictions are arbitrary
        if (_config.heartbeat < 60 seconds || _config.heartbeat > 2 days) revert IDIAOracle.InvalidHeartbeat();
    }
}