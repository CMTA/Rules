// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title IDecimals — token decimals query.
 * @notice Optional ERC-20 metadata getter, used to cross-check a configured decimals value
 * against the token's own on-chain metadata. Tokens are not required to implement it.
 */
interface IDecimals {
    /**
     * @notice Returns the number of decimals used by the token.
     * @return The token decimals.
     */
    function decimals() external view returns (uint8);
}
