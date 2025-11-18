// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import "./abstract/RuleAddressSet/invariantStorage/RuleBlacklistInvariantStorage.sol";
import "./abstract/RuleAddressSet/RuleAddressSet.sol";
import "./abstract/RuleValidateTransfer.sol";
//import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
/**
 * @title a blacklist manager
 */

contract RuleBlacklist is RuleValidateTransfer, RuleAddressSet, RuleBlacklistInvariantStorage {
    /**
     * @param admin Address of the contract (Access Control)
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     */
    constructor(address admin, address forwarderIrrevocable) RuleAddressSet(admin, forwarderIrrevocable) {}

    /**
     * @notice Check if an addres is in the whitelist or not
     * @param from the origin address
     * @param to the destination address
     * @return The restricion code or REJECTED_CODE_BASE.TRANSFER_OK
     *
     */
    function detectTransferRestriction(address from, address to, uint256 /* value */ )
        public
        view
        override
        returns (uint8)
    {
        if (isAddressListed(from)) {
            return CODE_ADDRESS_FROM_IS_BLACKLISTED;
        } else if (isAddressListed(to)) {
            return CODE_ADDRESS_TO_IS_BLACKLISTED;
        } else {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
    }

    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        public
        view
        override
        returns (uint8)
    {
        if (isAddressListed(spender)) {
            return CODE_ADDRESS_SPENDER_IS_BLACKLISTED;
        } else {
            return detectTransferRestriction(from, to, value);
        }
    }

    /**
     * @notice To know if the restriction code is valid for this rule or not.
     * @param _restrictionCode The target restriction code
     * @return true if the restriction code is known, false otherwise
     *
     */
    function canReturnTransferRestrictionCode(uint8 _restrictionCode) external pure override returns (bool) {
        return _restrictionCode == CODE_ADDRESS_FROM_IS_BLACKLISTED
            || _restrictionCode == CODE_ADDRESS_TO_IS_BLACKLISTED || _restrictionCode == CODE_ADDRESS_SPENDER_IS_BLACKLISTED;
    }

    /**
     * @notice Return the corresponding message
     * @param _restrictionCode The target restriction code
     * @return true if the transfer is valid, false otherwise
     *
     */
    function messageForTransferRestriction(uint8 _restrictionCode) external pure override returns (string memory) {
        if (_restrictionCode == CODE_ADDRESS_FROM_IS_BLACKLISTED) {
            return TEXT_ADDRESS_FROM_IS_BLACKLISTED;
        } else if (_restrictionCode == CODE_ADDRESS_TO_IS_BLACKLISTED) {
            return TEXT_ADDRESS_TO_IS_BLACKLISTED;
        } else if (_restrictionCode == CODE_ADDRESS_SPENDER_IS_BLACKLISTED) {
            return TEXT_ADDRESS_SPENDER_IS_BLACKLISTED;
        } else {
            return TEXT_CODE_NOT_FOUND;
        }
    }

    function transferred(address from, address to, uint256 value) public view {
        uint8 code = this.detectTransferRestriction(from, to, value);
        require(code == uint8(REJECTED_CODE_BASE.TRANSFER_OK), RuleBlacklist_InvalidTransfer(from, to, value, code));
    }

    function transferred(address spender, address from, address to, uint256 value) public view {
        uint8 code = this.detectTransferRestrictionFrom(spender, from, to, value);
        require(code == uint8(REJECTED_CODE_BASE.TRANSFER_OK), RuleBlacklist_InvalidTransfer(from, to, value, code));
    }
}
