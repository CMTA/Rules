// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {ISanctionsList} from "../../rules/interfaces/ISanctionsList.sol";
import {RuleSanctionsList} from "../../rules/validation/deployment/RuleSanctionsList.sol";

/**
 * @title SanctionsListExtraCheckHarness
 * @notice A subclass that adds a screening check which does NOT depend on the sanctions oracle
 *         (`CLAUDE_ANALYSIS.md` F-2).
 * @dev This is the shape that exposes the defect. `_detectTransferRestrictionFrom` used to nest its
 *      delegation to {_detectTransferRestriction} inside the `oracle != address(0)` branch, so with
 *      no oracle configured the `transferFrom` path returned `TRANSFER_OK` without ever calling the
 *      hook -- and this subclass's check silently did not apply there, while it did apply to a plain
 *      `transfer`. A compliance rule that screens one entrypoint and not the other is the failure
 *      this harness exists to catch.
 */
contract SanctionsListExtraCheckHarness is RuleSanctionsList {
    /**
     * @notice Restriction code returned for the extra, oracle-independent check.
     */
    uint8 public constant CODE_EXTRA_BLOCKED = 201;

    /**
     * @notice Address this subclass blocks regardless of what the oracle says.
     */
    address public immutable BLOCKED;

    constructor(address admin, address forwarderIrrevocable, ISanctionsList oracle_, address blocked)
        RuleSanctionsList(admin, forwarderIrrevocable, oracle_)
    {
        BLOCKED = blocked;
    }

    /**
     * @notice Applies the base sanctions screening, then the extra oracle-independent check.
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
