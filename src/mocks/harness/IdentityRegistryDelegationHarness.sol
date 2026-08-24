// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {RuleIdentityRegistry} from "../../rules/validation/deployment/RuleIdentityRegistry.sol";

/**
 * @title IdentityRegistryExtraCheckHarness
 * @notice A subclass that adds a screening check which does NOT depend on the identity registry
 *         (Nethermind AuditAgent NM-3, the mirror of `CLAUDE_ANALYSIS.md` F-2).
 * @dev This is the shape that exposes the defect. `_detectTransferRestrictionFrom` used to return
 *      `TRANSFER_OK` outright when the registry was unset or the transfer was a burn, instead of
 *      delegating to {_detectTransferRestriction}. A subclass extending only that hook -- the
 *      natural place to add a check -- therefore applied to `transfer` but silently not to
 *      `transferFrom` or `burnFrom`. A compliance rule that screens one entrypoint and not the
 *      other is the failure this harness exists to catch.
 */
contract IdentityRegistryExtraCheckHarness is RuleIdentityRegistry {
    /**
     * @notice Restriction code returned for the extra, registry-independent check.
     */
    uint8 public constant CODE_EXTRA_BLOCKED = 202;

    /**
     * @notice Address this subclass blocks regardless of what the registry says.
     */
    address public immutable BLOCKED;

    constructor(address admin, address identityRegistry_, bool checkSender_, bool checkSpender_, address blocked)
        RuleIdentityRegistry(admin, identityRegistry_, checkSender_, checkSpender_)
    {
        BLOCKED = blocked;
    }

    /**
     * @notice Applies the base identity screening, then the extra registry-independent check.
     */
    function _detectTransferRestriction(address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        uint8 code = super._detectTransferRestriction(from, to, value);
        if (code != uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)) {
            return code;
        }
        if (from == BLOCKED || to == BLOCKED) {
            return CODE_EXTRA_BLOCKED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }
}
