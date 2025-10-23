// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleWhitelistInvariantStorage} from "./RuleAddressSet/invariantStorage/RuleWhitelistInvariantStorage.sol";
import {RuleValidateTransfer} from "./RuleValidateTransfer.sol";

/**
 * @title Rule Whitelist Common
 * @notice Provides common logic for validating whitelist-based transfer restrictions.
 * @dev 
 * - Implements ERC-3643–compatible `transferred` hooks to enforce whitelist checks.
 * - Defines utility functions for restriction code validation and message mapping.
 * - Inherits restriction code constants and messages from {RuleWhitelistInvariantStorage}.
 */
abstract contract RuleWhitelistCommon is
    RuleValidateTransfer,
    RuleWhitelistInvariantStorage
{
    bool internal _checkSpender;



    /*//////////////////////////////////////////////////////////////
                          RESTRICTION CODE LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Checks whether a restriction code is recognized by this rule.
     * @dev 
     * Used to verify if a returned restriction code belongs to the whitelist rule.
     * @param restrictionCode The restriction code to validate.
     * @return isKnown True if the restriction code is recognized by this rule, false otherwise.
     */
    function canReturnTransferRestrictionCode(
        uint8 restrictionCode
    ) external pure override returns (bool isKnown) {
        return
            restrictionCode == CODE_ADDRESS_FROM_NOT_WHITELISTED ||
            restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED ||
            restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
    }

    /**
     * @notice Returns the human-readable message corresponding to a restriction code.
     * @dev 
     * Returns a descriptive text that explains why a transfer was restricted.
     * @param restrictionCode The restriction code to decode.
     * @return message A human-readable explanation of the restriction.
     */
    function messageForTransferRestriction(
        uint8 restrictionCode
    ) external pure override returns (string memory message) {
        if (restrictionCode == CODE_ADDRESS_FROM_NOT_WHITELISTED) {
            return TEXT_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED) {
            return TEXT_ADDRESS_TO_NOT_WHITELISTED;
        } else if (restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED) {
            return TEXT_ADDRESS_SPENDER_NOT_WHITELISTED;
        } else {
            return TEXT_CODE_NOT_FOUND;
        }
    }

    /*//////////////////////////////////////////////////////////////
                           ERC-3643 HOOKS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice ERC-3643 hook called when a transfer occurs.
     * @dev 
     * - Validates that both `from` and `to` addresses are whitelisted.  
     * - Reverts if any restriction code other than `TRANSFER_OK` is returned.  
     * - Should be called during token transfer logic to enforce whitelist compliance.
     * @param from The address sending tokens.
     * @param to The address receiving tokens.
     * @param value The token amount being transferred.
     */
    function transferred(address from, address to, uint256 value) public view {
        uint8 code = this.detectTransferRestriction(from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleWhitelist_InvalidTransfer(from, to, value, code)
        );
    }

    /**
     * @notice ERC-3643 hook called when a delegated transfer occurs (`transferFrom`).
     * @dev 
     * - Validates that `spender`, `from`, and `to` are all whitelisted.  
     * - Reverts if any restriction code other than `TRANSFER_OK` is returned.  
     * @param spender The address performing the transfer on behalf of another.
     * @param from The address from which tokens are transferred.
     * @param to The recipient address.
     * @param value The token amount being transferred.
     */
    function transferred(
        address spender,
        address from,
        address to,
        uint256 value
    ) public view {
        uint8 code = this.detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleWhitelist_InvalidTransfer(from, to, value, code)
        );
    }
}