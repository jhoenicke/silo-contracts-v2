// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC721} from "openzeppelin5/token/ERC721/ERC721.sol";

import {IShareTokenInitializable} from "./interfaces/IShareTokenInitializable.sol";
import {ISiloOracle} from "./interfaces/ISiloOracle.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {ISilo} from "./interfaces/ISilo.sol";
import {ISiloConfig, SiloConfig} from "./SiloConfig.sol";
import {Hook} from "./lib/Hook.sol";
import {Views} from "./lib/Views.sol";
import {CloneDeterministic} from "./lib/CloneDeterministic.sol";

contract SiloFactory is ISiloFactory, ERC721, Ownable2Step {
    /// @dev max fee is 40%, 1e18 == 100%
    uint256 public constant MAX_FEE = 0.4e18;

    /// @dev max percent is 1e18 == 100%
    uint256 public constant MAX_PERCENT = 1e18;

    uint256 public daoFee;
    uint256 public maxDeployerFee;
    uint256 public maxFlashloanFee;
    uint256 public maxLiquidationFee;
    address public daoFeeReceiver;

    string public baseURI;

    mapping(uint256 id => address siloConfig) public idToSiloConfig;
    mapping(address silo => bool) public isSilo;

    uint256 internal _siloId;

    constructor(
        uint256 _daoFee,
        address _daoFeeReceiver
    )
        ERC721("Silo Finance Fee Receiver", "feeSILO")
        Ownable(msg.sender)
    {
        // start IDs from 1
        _siloId = 1;

        baseURI = "https://v2.app.silo.finance/markets/";

        uint256 _maxDeployerFee = 0.15e18; // 15% max deployer fee
        uint256 _newMaxFlashloanFee = 0.15e18; // 15% max flashloan fee
        uint256 _newMaxLiquidationFee = 0.30e18; // 30% max liquidation fee

        _setDaoFee(_daoFee);
        _setDaoFeeReceiver(_daoFeeReceiver);

        _setMaxDeployerFee(_maxDeployerFee);
        _setMaxFlashloanFee(_newMaxFlashloanFee);
        _setMaxLiquidationFee(_newMaxLiquidationFee);
    }

    /// @inheritdoc ISiloFactory
    function createSilo(
        ISiloConfig.InitData memory _initData,
        ISiloConfig _siloConfig,
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl
    )
        external
        virtual
    {
        if (
            _siloImpl == address(0) ||
            _shareProtectedCollateralTokenImpl == address(0) ||
            _shareDebtTokenImpl == address(0) ||
            address(_siloConfig) == address(0)
        ) {
            revert ZeroAddress();
        }

        validateSiloInitData(_initData);

        ISiloConfig.ConfigData memory configData0;
        ISiloConfig.ConfigData memory configData1;

        (configData0, configData1) = Views.copySiloConfig(_initData);

        uint256 nextSiloId = _siloId;

        // safe to uncheck, because we will not create 2 ** 256 of silos in a lifetime
        unchecked { _siloId++; }

        configData0.daoFee = daoFee;
        configData1.daoFee = daoFee;

        _cloneShareTokens(
            configData0,
            configData1,
            _shareProtectedCollateralTokenImpl,
            _shareDebtTokenImpl,
            nextSiloId
        );

        configData0.silo = CloneDeterministic.silo0(_siloImpl, nextSiloId);
        configData1.silo = CloneDeterministic.silo1(_siloImpl, nextSiloId);

        ISilo(configData0.silo).initialize(_siloConfig);
        ISilo(configData1.silo).initialize(_siloConfig);

        _initializeShareTokens(configData0, configData1);

        ISilo(configData0.silo).updateHooks();
        ISilo(configData1.silo).updateHooks();

        idToSiloConfig[nextSiloId] = address(_siloConfig);

        isSilo[configData0.silo] = true;
        isSilo[configData1.silo] = true;

        if (_initData.deployer != address(0)) {
            _mint(_initData.deployer, nextSiloId);
        }

        emit NewSilo(configData0.token, configData1.token, configData0.silo, configData1.silo, address(_siloConfig));
    }

    /// @inheritdoc ISiloFactory
    function burn(uint256 _siloIdToBurn) external virtual {
        _burn(_siloIdToBurn);
    }

    /// @inheritdoc ISiloFactory
    function setDaoFee(uint256 _newDaoFee) external virtual onlyOwner {
        _setDaoFee(_newDaoFee);
    }

    /// @inheritdoc ISiloFactory
    function setMaxDeployerFee(uint256 _newMaxDeployerFee) external virtual onlyOwner {
        _setMaxDeployerFee(_newMaxDeployerFee);
    }

    /// @inheritdoc ISiloFactory
    function setMaxFlashloanFee(uint256 _newMaxFlashloanFee) external virtual onlyOwner {
        _setMaxFlashloanFee(_newMaxFlashloanFee);
    }

    /// @inheritdoc ISiloFactory
    function setMaxLiquidationFee(uint256 _newMaxLiquidationFee) external virtual onlyOwner {
        _setMaxLiquidationFee(_newMaxLiquidationFee);
    }

    /// @inheritdoc ISiloFactory
    function setDaoFeeReceiver(address _newDaoFeeReceiver) external virtual onlyOwner {
        _setDaoFeeReceiver(_newDaoFeeReceiver);
    }

    /// @inheritdoc ISiloFactory
    function setBaseURI(string calldata _newBaseURI) external virtual onlyOwner {
        baseURI = _newBaseURI;
    }

    /// @inheritdoc ISiloFactory
    function getNextSiloId() external view virtual returns (uint256) {
        return _siloId;
    }

    /// @inheritdoc ISiloFactory
    function getFeeReceivers(address _silo) external view virtual returns (address dao, address deployer) {
        uint256 siloID = ISilo(_silo).config().SILO_ID();
        return (daoFeeReceiver, _ownerOf(siloID));
    }

    /// @inheritdoc ISiloFactory
    function validateSiloInitData(ISiloConfig.InitData memory _initData) public view virtual returns (bool) {
        // solhint-disable-previous-line code-complexity
        if (_initData.hookReceiver == address(0)) revert MissingHookReceiver();

        if (_initData.token0 == address(0)) revert EmptyToken0();
        if (_initData.token1 == address(0)) revert EmptyToken1();

        if (_initData.token0 == _initData.token1) revert SameAsset();
        if (_initData.maxLtv0 == 0 && _initData.maxLtv1 == 0) revert InvalidMaxLtv();
        if (_initData.maxLtv0 > _initData.lt0) revert InvalidMaxLtv();
        if (_initData.maxLtv1 > _initData.lt1) revert InvalidMaxLtv();
        if (_initData.lt0 > MAX_PERCENT || _initData.lt1 > MAX_PERCENT) revert InvalidLt();

        if (_initData.maxLtvOracle0 != address(0) && _initData.solvencyOracle0 == address(0)) {
            revert OracleMisconfiguration();
        }

        if (_initData.callBeforeQuote0 && _initData.solvencyOracle0 == address(0)) revert InvalidCallBeforeQuote();

        if (_initData.maxLtvOracle1 != address(0) && _initData.solvencyOracle1 == address(0)) {
            revert OracleMisconfiguration();
        }

        if (_initData.callBeforeQuote1 && _initData.solvencyOracle1 == address(0)) revert InvalidCallBeforeQuote();

        _verifyQuoteTokens(_initData);

        if (_initData.deployerFee > 0 && _initData.deployer == address(0)) revert InvalidDeployer();
        if (_initData.deployerFee > maxDeployerFee) revert MaxDeployerFeeExceeded();
        if (_initData.flashloanFee0 > maxFlashloanFee) revert MaxFlashloanFeeExceeded();
        if (_initData.flashloanFee1 > maxFlashloanFee) revert MaxFlashloanFeeExceeded();
        if (_initData.liquidationFee0 > maxLiquidationFee) revert MaxLiquidationFeeExceeded();
        if (_initData.liquidationFee1 > maxLiquidationFee) revert MaxLiquidationFeeExceeded();

        if (_initData.interestRateModel0 == address(0) || _initData.interestRateModel1 == address(0)) {
            revert InvalidIrm();
        }

        return true;
    }

    /// @inheritdoc ERC721
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);

        return string.concat(
            baseURI,
            Strings.toString(block.chainid),
            "/",
            Strings.toHexString(idToSiloConfig[tokenId])
        );
    }

    function _setDaoFee(uint256 _newDaoFee) internal virtual {
        if (_newDaoFee > MAX_FEE) revert MaxFeeExceeded();

        daoFee = _newDaoFee;

        emit DaoFeeChanged(_newDaoFee);
    }

    function _setMaxDeployerFee(uint256 _newMaxDeployerFee) internal virtual {
        if (_newMaxDeployerFee > MAX_FEE) revert MaxFeeExceeded();

        maxDeployerFee = _newMaxDeployerFee;

        emit MaxDeployerFeeChanged(_newMaxDeployerFee);
    }

    function _setMaxFlashloanFee(uint256 _newMaxFlashloanFee) internal virtual {
        if (_newMaxFlashloanFee > MAX_FEE) revert MaxFeeExceeded();

        maxFlashloanFee = _newMaxFlashloanFee;

        emit MaxFlashloanFeeChanged(_newMaxFlashloanFee);
    }

    function _setMaxLiquidationFee(uint256 _newMaxLiquidationFee) internal virtual {
        if (_newMaxLiquidationFee > MAX_FEE) revert MaxFeeExceeded();

        maxLiquidationFee = _newMaxLiquidationFee;

        emit MaxLiquidationFeeChanged(_newMaxLiquidationFee);
    }

    function _setDaoFeeReceiver(address _newDaoFeeReceiver) internal virtual {
        if (_newDaoFeeReceiver == address(0)) revert ZeroAddress();

        daoFeeReceiver = _newDaoFeeReceiver;

        emit DaoFeeReceiverChanged(_newDaoFeeReceiver);
    }

    function _cloneShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _nextSiloId
    ) internal virtual {
        configData0.collateralShareToken = configData0.silo;
        configData1.collateralShareToken = configData1.silo;

        configData0.protectedShareToken = CloneDeterministic.shareProtectedCollateralToken0(
            _shareProtectedCollateralTokenImpl, _nextSiloId
        );

        configData1.protectedShareToken = CloneDeterministic.shareProtectedCollateralToken1(
            _shareProtectedCollateralTokenImpl, _nextSiloId
        );

        configData0.debtShareToken = CloneDeterministic.shareDebtToken0(_shareDebtTokenImpl, _nextSiloId);
        configData1.debtShareToken = CloneDeterministic.shareDebtToken1(_shareDebtTokenImpl, _nextSiloId);
    }

    function _initializeShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1
    ) internal virtual {
        uint24 protectedTokenType = uint24(Hook.PROTECTED_TOKEN);
        uint24 debtTokenType = uint24(Hook.DEBT_TOKEN);

        // initialize configData0
        ISilo silo0 = ISilo(configData0.silo);
        address hookReceiver0 = configData0.hookReceiver;

        IShareTokenInitializable(configData0.protectedShareToken).initialize(silo0, hookReceiver0, protectedTokenType);
        IShareTokenInitializable(configData0.debtShareToken).initialize(silo0, hookReceiver0, debtTokenType);

        // initialize configData1
        ISilo silo1 = ISilo(configData1.silo);
        address hookReceiver1 = configData1.hookReceiver;

        IShareTokenInitializable(configData1.protectedShareToken).initialize(silo1, hookReceiver1, protectedTokenType);
        IShareTokenInitializable(configData1.debtShareToken).initialize(silo1, hookReceiver1, debtTokenType);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _verifyQuoteTokens(ISiloConfig.InitData memory _initData) internal virtual view {
        address expectedQuoteToken;

        expectedQuoteToken = _verifyQuoteToken(expectedQuoteToken, _initData.solvencyOracle0);
        expectedQuoteToken = _verifyQuoteToken(expectedQuoteToken, _initData.maxLtvOracle0);
        expectedQuoteToken = _verifyQuoteToken(expectedQuoteToken, _initData.solvencyOracle1);
        expectedQuoteToken = _verifyQuoteToken(expectedQuoteToken, _initData.maxLtvOracle1);
    }

    function _verifyQuoteToken(address _expectedQuoteToken, address _oracle)
        internal
        virtual
        view
        returns (address quoteToken)
    {
        if (_oracle == address(0)) return _expectedQuoteToken;

        quoteToken = ISiloOracle(_oracle).quoteToken();

        if (_expectedQuoteToken == address(0)) return quoteToken;
        if (_expectedQuoteToken != quoteToken) revert InvalidQuoteToken();
    }
}
