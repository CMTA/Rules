// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title IERC2980
 * @notice Interface for ERC-2980 Swiss Compliant Asset Token whitelist and frozenlist getters.
 * @dev
 * Implements the mandatory `ERC2980` interface from https://eips.ethereum.org/EIPS/eip-2980.
 *
 * Deviation from the ERC-2980 `Whitelistable` and `Freezable` example interfaces:
 * The spec's single-address management functions (`addAddressToWhitelist`, `removeAddressFromWhitelist`,
 * `addAddressToFrozenlist`, `removeAddressFromFrozenlist`) return a `bool` indicating whether the
 * operation changed state and do NOT revert on duplicates or missing entries.
 * This implementation uses a different naming convention and instead reverts on invalid
 * single-item operations (duplicate add or missing remove), consistent with the codebase convention.
 * Batch operations remain non-reverting as per convention.
 */
interface IERC2980 {
    /**
     * @dev Returns true if the address is in the frozenlist.
     * Frozen addresses cannot send or receive tokens.
     * @param _operator The address to check.
     * @return True if the address is in the frozenlist, otherwise false.
     */
    function frozenlist(address _operator) external view returns (bool);

    /**
     * @dev Returns true if the address is in the whitelist.
     * Only whitelisted addresses can receive tokens.
     * @param _operator The address to check.
     * @return True if the address is in the whitelist, otherwise false.
     */
    function whitelist(address _operator) external view returns (bool);
}
