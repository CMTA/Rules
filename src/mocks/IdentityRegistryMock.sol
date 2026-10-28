// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {IIdentityRegistryVerified} from "../rules/interfaces/IIdentityRegistry.sol";

/**
 * @title IdentityRegistryMock — test double for an ERC-3643 identity registry
 * @notice Stores per-address verification status for use in tests.
 */
contract IdentityRegistryMock is IIdentityRegistryVerified {
    /**
     * @notice Verification status keyed by address.
     */
    mapping(address => bool) private verified;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the verification status of an address.
     * @param user The address to update.
     * @param verified_ The verification status to assign.
     */
    function setVerified(address user, bool verified_) external {
        verified[user] = verified_;
    }

    /**
     * @notice Returns whether an address is verified.
     * @param user The address to query.
     * @return True if the address is verified.
     */
    function isVerified(address user) external view returns (bool) {
        return verified[user];
    }
}
