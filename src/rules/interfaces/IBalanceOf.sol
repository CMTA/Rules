// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title IBalanceOf — single-account balance query.
 * @dev Declared here rather than importing a full `IERC20` so the rule depends on exactly the one
 * function it calls, matching {ITotalSupply}. `balanceOf` is the only token surface
 * {RuleMaxBalanceBase} needs.
 */
interface IBalanceOf {
    /**
     * @notice Returns the token balance of `account`.
     * @param account The address to query.
     * @return The balance held by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
}
