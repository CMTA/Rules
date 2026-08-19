// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleAddressSet} from "../RuleAddressSet/RuleAddressSet.sol";
import {RuleNFTAdapter} from "../core/RuleNFTAdapter.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {RuleSpenderWhitelistInvariantStorage} from "../invariant/RuleSpenderWhitelistInvariantStorage.sol";
import {AddressListInterfaceId} from "../../../interfaces/library/AddressListInterfaceId.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";

/**
 * @title RuleSpenderWhitelistBase
 * @notice Restricts `transferFrom`-style flows to whitelisted spenders only.
 * @dev Direct transfers (`transferred(from,to,value)`) are intentionally no-op.
 *
 * @dev **Deliberately does NOT implement {IAddressListPolarity}, and must not be made to.** Its set is
 * an allow-list, so declaring `isAllowList() == true` would be honest about polarity and still wrong:
 * the listed addresses are permitted **spenders**, not permitted **holders**. Declaring polarity would
 * let `RuleWhitelistWrapper` accept this rule and then read whitelisted spenders as eligible transfer
 * participants. Withholding the declaration is what makes the wrapper's fail-closed check refuse it.
 * Polarity is only half the question; the other half is what the addresses are.
 */
abstract contract RuleSpenderWhitelistBase is RuleAddressSet, RuleNFTAdapter, RuleSpenderWhitelistInvariantStorage {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the spender-whitelist rule base.
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address for meta-transactions.
     */
    constructor(address forwarderIrrevocable) RuleAddressSet(forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this rule can emit the given restriction code.
     * @param restrictionCode The restriction code to check.
     * @return True if the code is produced by this rule.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Regular transfers are always accepted by this rule.
     */
    function transferred(address, address, uint256) public view override(IERC3643IComplianceContract) {}

    /**
     * @inheritdoc IRuleEngine
     */
    function transferred(address spender, address from, address to, uint256 value) public view override(IRuleEngine) {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED) {
            return TEXT_ADDRESS_SPENDER_NOT_WHITELISTED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(RuleTransferValidation) returns (bool) {
        // Advertise IAddressList: this rule manages an address set and is callable through
        // the IAddressList interface.
        return interfaceId == AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID
            || interfaceId == AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID
            || RuleTransferValidation.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Direct transfers are always accepted by this rule.
     * @return Always TRANSFER_OK.
     */
    function _detectTransferRestriction(address, address, uint256) internal pure virtual override returns (uint8) {
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Detects whether a delegated transfer is blocked because the spender is not whitelisted.
     * @param spender The delegated spender address.
     * @param from The sender address.
     * @param to The recipient address.
     * @return The restriction code, or TRANSFER_OK when allowed.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        // Mint (from == address(0)) and burn (to == address(0)) are exempt from the spender check:
        // the minter/burner acts on its own authority, not as a delegated ERC-20 spender.
        if (from != address(0) && to != address(0) && !_isAddressListed(spender)) {
            return CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice No-op: regular transfers are intentionally ignored by this rule.
     */
    function _transferred(address, address, uint256) internal view virtual override {
        // no-op: regular transfers are intentionally ignored by this rule
    }

    /**
     * @notice Reverts if a delegated transfer is blocked because the spender is not whitelisted.
     * @param spender The delegated spender address.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleSpenderWhitelist_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
