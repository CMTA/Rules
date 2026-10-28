// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {ISanctionsList} from "../rules/interfaces/ISanctionsList.sol";

/**
 * @title SanctionListOracle — test double for a Chainalysis-style sanctions oracle
 * @notice Stores per-address sanctioned status for use in tests.
 */
contract SanctionListOracle is ISanctionsList {
    /**
     * @notice Sanctioned status keyed by address.
     */
    mapping(address => bool) private sanctionedAddresses;

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Marks an address as sanctioned.
     * @param newSanction The address to sanction.
     */
    function addToSanctionsList(address newSanction) public {
        sanctionedAddresses[newSanction] = true;
    }

    /**
     * @notice Removes an address from the sanctions list.
     * @param removeSanction The address to un-sanction.
     */
    function removeFromSanctionsList(address removeSanction) public {
        sanctionedAddresses[removeSanction] = false;
    }

    /**
     * @notice Returns whether an address is sanctioned.
     * @param addr The address to query.
     * @return True if the address is sanctioned.
     */
    function isSanctioned(address addr) public view returns (bool) {
        return sanctionedAddresses[addr];
    }
}
