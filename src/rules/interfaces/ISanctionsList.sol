// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

/**
 * @title ISanctionsList — sanctions oracle membership query.
 */
interface ISanctionsList {
    /**
     * @notice Returns whether the given address is sanctioned.
     * @param addr The address to check.
     * @return True if the address is sanctioned, otherwise false.
     */
    function isSanctioned(address addr) external view returns (bool);
}
