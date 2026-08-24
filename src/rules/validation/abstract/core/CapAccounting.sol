// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/**
 * @title CapAccounting
 * @notice The one question every cap rule ends in: would adding `value` leave an observed figure
 * above its cap? Owns that arithmetic; knows nothing about where either number came from.
 *
 * @dev Declares **no storage** and no constructor, so adding it to a rule's inheritance chain cannot
 * move a slot, and an upgradeable variant may adopt it freely.
 *
 * @dev Deliberately carries **no notion of pre- or post-update accounting**. Whether the observation
 * already includes the value being moved depends on WHICH PATH is running, not on the rule: a
 * pre-flight view always runs before the movement, while the write hook runs after it on a token that
 * notifies afterwards. A single flag here would answer for both and silently make the pre-flight view
 * disagree with enforcement. That distinction belongs one level up, in each rule's
 * `_detectTransferRestrictionOnNotify` hook.
 */
abstract contract CapAccounting {
    /**
     * @notice Whether adding `value` to `observed` would pass `cap`.
     * @dev Never reverts and never overflows: the projected total is never formed, the comparison is
     * against the remaining headroom instead. Both matter because every caller sits on a
     * MUST-NOT-revert ERC-1404 read path. Pass `value = 0` to ask only whether `observed` is already
     * over the cap -- which is exactly the question a post-update notification needs to answer.
     * @param observed The figure read for this check: a holder's balance, or a total supply.
     * @param cap The ceiling `observed` may not pass.
     * @param value The amount being added, or `0` when it is already counted in `observed`.
     * @return True when the result would breach the cap.
     */
    function _capExceededBy(uint256 observed, uint256 cap, uint256 value) internal pure virtual returns (bool) {
        // Already over the line whatever is added. Also guarantees the subtraction below.
        if (observed > cap) {
            return true;
        }
        return value > cap - observed;
    }

    /**
     * @notice How much may still be added before `observed` reaches `cap`.
     * @param observed The figure read for this check.
     * @param cap The ceiling.
     * @return The remaining headroom; `0` when already at or over the cap.
     */
    function _capHeadroom(uint256 observed, uint256 cap) internal pure virtual returns (uint256) {
        return observed >= cap ? 0 : cap - observed;
    }
}
