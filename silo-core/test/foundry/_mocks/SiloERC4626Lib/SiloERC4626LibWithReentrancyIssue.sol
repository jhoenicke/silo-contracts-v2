// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

// solhint-disable function-max-lines

library SiloERC4626LibWithReentrancyIssue {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // deposit fn with reentrancy issue
    // original code can be found here:
    // https://github.com/silo-finance/silo-contracts-v2/blob/06378822519ad8f164e7c18a4d3f8954d773ce60/silo-core/contracts/lib/SiloERC4626Lib.sol#L134
    function deposit(
        address _token,
        address _depositor,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        IShareToken _collateralShareToken,
        IShareToken _debtShareToken,
        ISilo.Assets storage _totalCollateral
    ) public returns (uint256 assets, uint256 shares) {
        if (!depositPossible(address(_debtShareToken), _receiver)) {
            revert ISilo.DepositNotPossible();
        }

        uint256 totalAssets = _totalCollateral.assets;

        (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalAssets,
            _collateralShareToken.totalSupply(),
            MathUpgradeable.Rounding.Up,
            MathUpgradeable.Rounding.Down,
            ISilo.AssetType.Collateral
        );

        if (_token != address(0)) {
            // Transfer tokens before minting. No state changes have been made so reentrancy does nothing
            IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), assets);
        }

        // `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
        unchecked {
            _totalCollateral.assets = totalAssets + assets;
        }
        
        // Hook receiver is called after `mint` and can reentry but state changes are completed already
        _collateralShareToken.mint(_receiver, _depositor, shares);
    }

    /// @notice Checks if a depositor can make a deposit
    /// @param _debtShareToken Address of the debt share token
    /// @param _depositor Address of the user attempting to deposit
    /// @return Returns `true` if the depositor can deposit, otherwise `false`
    function depositPossible(address _debtShareToken, address _depositor) public view returns (bool) {
        return IShareToken(_debtShareToken).balanceOf(_depositor) == 0;
    }
}