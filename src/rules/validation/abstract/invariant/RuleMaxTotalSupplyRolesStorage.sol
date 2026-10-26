// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

/**
 * @title RuleMaxTotalSupplyRolesStorage — the role gating cap changes on the AccessControl deployables.
 * @dev Inherited by `RuleMaxTotalSupply` and `RuleIssuanceCap` (and the ERC-3643 variant through the former),
 *      not by the shared invariant storage: the Ownable2Step variants gate the same functions on the owner and
 *      must not publish a role they never check.
 */
abstract contract RuleMaxTotalSupplyRolesStorage {
    /**
     * @notice Role allowed to change the cap (`setMaxTotalSupply`, `increaseMaxTotalSupply`,
     * `decreaseMaxTotalSupply`). Repointing the observed token is not included; `DEFAULT_ADMIN_ROLE` holds
     * this role implicitly.
     */
    bytes32 public constant MAX_TOTAL_SUPPLY_ROLE = keccak256("MAX_TOTAL_SUPPLY_ROLE");
}
