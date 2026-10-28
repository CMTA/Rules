// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title ITotalSupply — total supply query.
 */
interface ITotalSupply {
    /**
     * @notice Returns the current total supply of the token.
     * @return The total supply.
     */
    function totalSupply() external view returns (uint256);
}
