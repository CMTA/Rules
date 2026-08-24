// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IIdentityRegistryContains} from "./IIdentityRegistry.sol";

/**
 * @title IAddressListBatchQuery — the batch membership question, and nothing else.
 * @notice The minimum a contract must expose to be usable as a child of `RuleWhitelistWrapper`.
 * @dev Split out of {IAddressList} deliberately. The wrapper calls exactly one function on its
 * children, so demanding the whole of {IAddressList} — which also carries four write functions, two
 * further read functions and `contains` — would reject a perfectly serviceable read-only child.
 * ERC-165 checks should ask for what is actually called.
 *
 * WARNING: this interface conveys **membership, not polarity**. It says whether an address is in the
 * implementer's set, never whether being in that set means "allowed" or "denied". A deny-list
 * implements it just as faithfully as an allow-list, so no ERC-165 check can tell them apart; a
 * consumer that reads `true` as "eligible" must constrain its children by configuration.
 */
interface IAddressListBatchQuery {
    /**
     * @notice Checks multiple addresses for listing status.
     * @param targetAddresses Array of addresses to check.
     * @return results Boolean array aligned by index with listing results.
     */
    function areAddressesListed(address[] memory targetAddresses) external view returns (bool[] memory results);
}

/**
 * @title IAddressListPolarity — what membership of the set MEANS.
 * @notice The half of an address list that {IAddressListBatchQuery} cannot express.
 * @dev `areAddressesListed` reports *membership*; it says nothing about whether being a member is a
 * permission or a prohibition. An allow-list and a deny-list implement that interface identically and
 * advertise the same ERC-165 id, so a consumer reading `true` as "eligible" cannot tell them apart —
 * add a deny-list to an allow-list aggregator and its blocked addresses silently become permitted.
 *
 * Declaring polarity explicitly is what makes it checkable. A consumer requires this interface via
 * ERC-165 and then reads {isAllowList}, so a wrong-polarity list is refused at configuration time
 * instead of inverting the consumer's meaning at run time.
 *
 * WARNING: polarity is not the only way a list can be the wrong list. It says nothing about WHO the
 * listed addresses are — a rule listing permitted *spenders* is an allow-list and still meaningless
 * to a consumer screening *holders*. A contract whose set is not about the subject its consumers
 * screen should decline to implement this interface at all, so a fail-closed consumer refuses it.
 */
interface IAddressListPolarity {
    /**
     * @notice Whether membership of this contract's address set means ALLOWED.
     * @return allowed True when listed addresses are the permitted ones (an allow-list); false when
     * listed addresses are the prohibited ones (a deny-list).
     */
    function isAllowList() external view returns (bool allowed);
}

/**
 * @title IAddressList — interface for managing and querying a set of addresses.
 * @dev Inherits {IAddressListBatchQuery}; the flattened selector set is unchanged, so
 * {AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID} keeps its value.
 */
interface IAddressList is IIdentityRegistryContains, IAddressListBatchQuery {
    /* ============ Events ============ */
    /**
     * @notice Emitted when a batch add completes.
     * @dev `targetAddresses` is the input array as submitted, NOT the set of addresses that changed
     * state: a batch skips entries already present. `added` and `skipped` describe the effect, so a
     * consumer can tell a batch of 100 new members from 100 no-ops without replaying the whole
     * event history. The two always sum to `targetAddresses.length`.
     * @param targetAddresses The array submitted by the caller.
     * @param added Number of addresses newly inserted.
     * @param skipped Number of addresses already present, left untouched.
     */
    event AddAddresses(address[] targetAddresses, uint256 added, uint256 skipped);

    /**
     * @notice Emitted when a batch remove completes.
     * @dev See {AddAddresses}: `targetAddresses` is the input, `removed` and `skipped` are the effect.
     * @param targetAddresses The array submitted by the caller.
     * @param removed Number of addresses actually removed.
     * @param skipped Number of addresses that were not present.
     */
    event RemoveAddresses(address[] targetAddresses, uint256 removed, uint256 skipped);

    /**
     * @notice Emitted when a single address is added.
     * @param targetAddress The added address.
     */
    event AddAddress(address indexed targetAddress);

    /**
     * @notice Emitted when a single address is removed.
     * @param targetAddress The removed address.
     */
    event RemoveAddress(address indexed targetAddress);

    /* ============ Write ============ */
    /**
     * @notice Adds multiple addresses to the set.
     * @dev Does not revert if some addresses are already listed.
     * @param targetAddresses The addresses to add.
     */
    function addAddresses(address[] calldata targetAddresses) external;

    /**
     * @notice Removes multiple addresses from the set.
     * @dev Does not revert if some addresses are not listed.
     * @param targetAddresses The addresses to remove.
     */
    function removeAddresses(address[] calldata targetAddresses) external;

    /**
     * @notice Adds a single address to the set.
     * @dev Reverts if the address is already listed.
     * @param targetAddress The address to add.
     */
    function addAddress(address targetAddress) external;

    /**
     * @notice Removes a single address from the set.
     * @dev Reverts if the address is not listed.
     * @param targetAddress The address to remove.
     */
    function removeAddress(address targetAddress) external;

    /* ============ Read ============ */

    /**
     * @notice Returns the number of currently listed addresses.
     * @return count The number of listed addresses.
     */
    function listedAddressCount() external view returns (uint256 count);

    /**
     * @notice Checks whether the provided address is listed.
     * @param targetAddress The address to check.
     * @return isListed True if listed, otherwise false.
     */
    function isAddressListed(address targetAddress) external view returns (bool isListed);
}
