// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/* ==== Abtract contracts === */
import {RuleAddressSet} from "./abstract/RuleAddressSet/RuleAddressSet.sol";
import {RuleWhitelistCommon} from "./abstract/RuleWhitelistCommon.sol";
/* ==== CMTAT === */
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
/* ==== Interfaces === */
import {IIdentityRegistryVerified} from "../interfaces/IIdentityRegistry.sol";
import {
    IERC7943NonFungibleCompliance,
    IERC7943NonFungibleComplianceExtend
} from "../interfaces/IERC7943NonFungibleCompliance.sol";

/**
 * @title Rule Whitelist
 * @notice Manages a whitelist of authorized addresses and enforces whitelist-based transfer restrictions.
 * @dev
 * - Inherits core address management logic from {RuleAddressSet}.
 * - Integrates restriction code logic from {RuleWhitelistCommon}.
 * - Implements {IERC1404} to return specific restriction codes for non-whitelisted transfers.
 */
contract RuleWhitelist is RuleAddressSet, RuleWhitelistCommon, IIdentityRegistryVerified {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @param admin Address of the contract (Access Control)
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     */
    constructor(address admin, address forwarderIrrevocable, bool checkSpender_)
        RuleAddressSet(admin, forwarderIrrevocable)
    {
        checkSpender = checkSpender_;
    }

    /* ============  View Functions ============ */

    /**
     * @notice Detects whether a transfer between two addresses is allowed under the whitelist rule.
     * @dev
     * - Returns a restriction code indicating why a transfer is blocked.
     * - Implements the `IERC1404.detectTransferRestriction` interface.
     * @param from The address sending tokens.
     * @param to The address receiving tokens.
     * @return code Restriction code (e.g., `TRANSFER_OK` or specific whitelist rejection).
     *
     * | Condition | Returned Code |
     * |------------|---------------|
     * | `from` not whitelisted | `CODE_ADDRESS_FROM_NOT_WHITELISTED` |
     * | `to` not whitelisted | `CODE_ADDRESS_TO_NOT_WHITELISTED` |
     * | Both whitelisted | `TRANSFER_OK` |
     */
    function detectTransferRestriction(address from, address to, uint256 /* value */ )
        public
        view
        override(IERC1404)
        returns (uint8 code)
    {
        if (!isAddressListed(from)) {
            return CODE_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (!isAddressListed(to)) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        } else {
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function detectTransferRestriction(address from, address to, uint256, /* tokenId */ uint256 value)
        public
        view
        override(IERC7943NonFungibleComplianceExtend)
        returns (uint8)
    {
        return detectTransferRestriction(from, to, value);
    }

    /**
     * @notice Detects transfer restriction for delegated transfers (`transferFrom`).
     * @dev
     * - Checks the `spender`, `from`, and `to` addresses for whitelist compliance.
     * - Implements `IERC1404Extend.detectTransferRestrictionFrom`.
     * @param spender The address initiating the transfer on behalf of another.
     * @param from The address from which tokens are transferred.
     * @param to The address receiving the tokens.
     * @param value The amount being transferred (unused in this check).
     * @return code Restriction code, or `TRANSFER_OK` if all parties are whitelisted.
     *
     * | Condition | Returned Code |
     * |------------|---------------|
     * | `spender` not whitelisted | `CODE_ADDRESS_SPENDER_NOT_WHITELISTED` |
     * | `from` or `to` not whitelisted | respective restriction code from `detectTransferRestriction` |
     * | All whitelisted | `TRANSFER_OK` |
     */
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        public
        view
        override(IERC1404Extend)
        returns (uint8 code)
    {
        if (checkSpender && !isAddressListed(spender)) {
            return CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
        }
        return detectTransferRestriction(from, to, value);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function detectTransferRestrictionFrom(
        address spender,
        address from,
        address to,
        uint256, /* tokenId */
        uint256 value
    ) public view override(IERC7943NonFungibleComplianceExtend) returns (uint8) {
        return detectTransferRestrictionFrom(spender, from, to, value);
    }

    /**
     * @notice Checks whether a specific address is currently listed.
     * @param targetAddress The address to check.
     * @return isListed True if listed, false otherwise.
     */
    function isVerified(address targetAddress)
        public
        view
        override(IIdentityRegistryVerified)
        returns (bool isListed)
    {
        isListed = _isAddressListed(targetAddress);
    }
}
