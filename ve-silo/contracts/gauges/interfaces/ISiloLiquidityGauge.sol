// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface ISiloLiquidityGauge {
    function initialize(uint256 relativeWeightCap, address erc20BalancesHandler) external;
    // solhint-disable func-name-mixedcase
    // solhint-disable func-param-name-mixedcase
    // solhint-disable var-name-mixedcase

    function balance_updated_for_user(
        address _user,
        uint256 _user_new_balancer,
        uint256 _total_supply
    )
        external
        returns (bool);

    function balance_updated_for_users(
        address _user1,
        uint256 _user1_new_balancer,
        address _user2,
        uint256 _user2_new_balancer,
        uint256 _total_supply
    )
        external
        returns (bool);

    function user_checkpoint(address _addr) external returns (bool);

    /// @notice Returns ERC-20 Balancer handler
    function bal_handler() external view returns (address);
    /// @notice Get the timestamp of the last checkpoint
    function integrate_checkpoint() external view returns (uint256);
    /// @notice ∫(balance * rate(t) / totalSupply(t) dt) from 0 till checkpoint
    function integrate_fraction(address _user) external view returns (uint256);

    function working_supply() external view returns (uint256);
    function working_balances(address _user) external view returns (uint256);

    // solhint-enable func-name-mixedcase
    // solhint-enable func-param-name-mixedcase
    // solhint-enable var-name-mixedcase

    function getRelativeWeightCap() external view returns (uint256);
}