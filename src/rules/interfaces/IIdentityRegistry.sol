// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

/**
 * @title IIdentityRegistryVerified — identity registry verification query.
 */
interface IIdentityRegistryVerified {
    // registry consultation
    /**
     * @notice Returns whether the given address has a verified identity in the registry.
     * @param _userAddress The address to check.
     * @return True if the address is verified, otherwise false.
     */
    function isVerified(address _userAddress) external view returns (bool);
}

/**
 * @title IIdentityRegistryContains — identity registry membership query.
 */
interface IIdentityRegistryContains {
    // registry consultation
    /**
     * @notice Returns whether the given address is present in the registry.
     * @param _userAddress The address to check.
     * @return True if the address is contained in the registry, otherwise false.
     */
    function contains(address _userAddress) external view returns (bool);
}
