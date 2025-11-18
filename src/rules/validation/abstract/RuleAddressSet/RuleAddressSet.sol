// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {AccessControl} from "OZ/access/AccessControl.sol";
import {MetaTxModuleStandalone, ERC2771Context, Context} from "./../../../../modules/MetaTxModuleStandalone.sol";
import {RuleAddressSetInternal} from "./RuleAddressSetInternal.sol";
import {RuleAddressSetInvariantStorage} from "./invariantStorage/RuleAddressSetInvariantStorage.sol";
import {IIdentityRegistryContains} from "../../../interfaces/IIdentityRegistry.sol";
/**
 * @title Rule Address Set
 * @notice Manages a permissioned set of addresses related to rule logic.
 * @dev
 * - Provides controlled functions for adding and removing addresses.
 * - Integrates `AccessControl` for role-based access.
 * - Supports gasless transactions via ERC-2771 meta-transactions.
 * - Extends internal logic defined in {RuleAddressSetInternal}.
 */

abstract contract RuleAddressSet is
    AccessControl,
    MetaTxModuleStandalone,
    RuleAddressSetInternal,
    RuleAddressSetInvariantStorage,
    IIdentityRegistryContains
{
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Cached number of currently listed addresses.
    uint256 private _listedAddressCountCache;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the RuleAddressSet contract.
     * @param admin The address granted the default admin role.
     * @param forwarderIrrevocable Address of the ERC2771 forwarder (for meta-transactions).
     * @dev Reverts if the admin address is the zero address.
     */
    constructor(address admin, address forwarderIrrevocable) MetaTxModuleStandalone(forwarderIrrevocable) {
        if (admin == address(0)) {
            revert RuleAddressSet_AdminWithAddressZeroNotAllowed();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                              CORE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the set.
     * @dev
     * - Does not revert if an address is already listed.
     * - Accessible only by accounts with the `ADDRESS_LIST_ADD_ROLE`.
     * @param targetAddresses Array of addresses to be added.
     */
    function addAddresses(address[] calldata targetAddresses) public onlyRole(ADDRESS_LIST_ADD_ROLE) {
        _addAddresses(targetAddresses);
        emit AddAddresses(targetAddresses);
    }

    /**
     * @notice Removes multiple addresses from the set.
     * @dev
     * - Does not revert if an address is not listed.
     * - Accessible only by accounts with the `ADDRESS_LIST_REMOVE_ROLE`.
     * @param targetAddresses Array of addresses to remove.
     */
    function removeAddresses(address[] calldata targetAddresses) public onlyRole(ADDRESS_LIST_REMOVE_ROLE) {
        _removeAddresses(targetAddresses);
        emit RemoveAddresses(targetAddresses);
    }

    /**
     * @notice Adds a single address to the set.
     * @dev
     * - Reverts if the address is already listed.
     * - Accessible only by accounts with the `ADDRESS_LIST_ADD_ROLE`.
     * @param targetAddress The address to be added.
     */
    function addAddress(address targetAddress) public onlyRole(ADDRESS_LIST_ADD_ROLE) {
        if (_isAddressListed(targetAddress)) {
            revert RuleAddressSet_AddressAlreadyListed();
        }
        _addAddress(targetAddress);
        emit AddAddress(targetAddress);
    }

    /**
     * @notice Removes a single address from the set.
     * @dev
     * - Reverts if the address is not listed.
     * - Accessible only by accounts with the `ADDRESS_LIST_REMOVE_ROLE`.
     * @param targetAddress The address to be removed.
     */
    function removeAddress(address targetAddress) public onlyRole(ADDRESS_LIST_REMOVE_ROLE) {
        if (!_isAddressListed(targetAddress)) {
            revert RuleAddressSet_AddressNotFound();
        }
        _removeAddress(targetAddress);
        emit RemoveAddress(targetAddress);
    }

    /**
     * @notice Returns the total number of currently listed addresses.
     * @return count The number of listed addresses.
     */
    function listedAddressCount() public view returns (uint256 count) {
        count = _listedAddressCount();
    }

    /**
     * @notice Checks whether a specific address is currently listed.
     * @param targetAddress The address to check.
     * @return isListed True if listed, false otherwise.
     */
    function contains(address targetAddress) public view override(IIdentityRegistryContains) returns (bool isListed) {
        isListed = _isAddressListed(targetAddress);
    }

    /**
     * @notice Checks whether a specific address is currently listed.
     * @param targetAddress The address to check.
     * @return isListed True if listed, false otherwise.
     */
    function isAddressListed(address targetAddress) public view returns (bool isListed) {
        isListed = _isAddressListed(targetAddress);
    }

    /**
     * @notice Checks multiple addresses in a single call.
     * @param targetAddresses Array of addresses to check.
     * @return results Array of booleans corresponding to listing status.
     */
    function areAddressesListed(address[] memory targetAddresses) public view returns (bool[] memory results) {
        results = new bool[](targetAddresses.length);
        for (uint256 i = 0; i < targetAddresses.length; ++i) {
            results[i] = _isAddressListed(targetAddresses[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns `true` if `account` has been granted `role`.
     * @dev
     * The `DEFAULT_ADMIN_ROLE` implicitly grants all roles.
     * @param role The role identifier.
     * @param account The account address to check.
     */
    function hasRole(bytes32 role, address account) public view virtual override(AccessControl) returns (bool) {
        if (AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        }
        return AccessControl.hasRole(role, account);
    }

    /*//////////////////////////////////////////////////////////////
                             ERC-2771 META TX
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ERC2771Context
    function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /// @inheritdoc ERC2771Context
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /// @inheritdoc ERC2771Context
    function _contextSuffixLength() internal view override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
