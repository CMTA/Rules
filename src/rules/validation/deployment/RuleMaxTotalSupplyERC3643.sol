// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleMaxTotalSupply} from "./RuleMaxTotalSupply.sol";

/**
 * @title RuleMaxTotalSupplyERC3643
 * @notice {RuleMaxTotalSupply} for **ERC-3643 tokens only**. Identical supply-cap logic; the sole difference is WHEN the
 * token reports the mint.
 *
 * @dev **Use this variant if and only if the token calls compliance AFTER it has moved the value.** ERC-3643 /
 * T-REX does: `mint` runs `_mint` and only then `_tokenCompliance.created`, so `totalSupply()` already includes
 * the new tokens. CMTAT calls the rule first and must use plain {RuleMaxTotalSupply}.
 *
 * @dev **Picking the wrong variant breaks the cap silently, and nothing reverts at configuration time.** The
 * stock rule on ERC-3643 counts the minted amount twice and rejects mints that are within the configured ceiling; this variant
 * on CMTAT ignores the pending amount and weakens enforcement.
 *
 * @dev Only the WRITE path is re-phased — the read views still project the pending amount, because ERC-3643
 * calls `canTransfer` before `_mint`.
 */
contract RuleMaxTotalSupplyERC3643 is RuleMaxTotalSupply {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address that receives the default admin role.
     * @param tokenContract_ Token contract that exposes totalSupply (must be non-zero).
     * @param maxTotalSupply_ Initial maximum supply.
     */
    constructor(address admin, address tokenContract_, uint256 maxTotalSupply_)
        RuleMaxTotalSupply(admin, tokenContract_, maxTotalSupply_)
    {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enforcement for a token that reports the mint after performing it.
     * @dev Re-asks the standard check with nothing left to add: `totalSupply()` already includes the
     * minted amount, so the comparison reduces to "is the post-mint supply within the ceiling".
     * @param from Sender address; the zero address denotes the mint this rule gates.
     * @param to Recipient address.
     * @return The restriction code the write hook enforces.
     */
    function _detectTransferRestrictionOnNotify(
        address from,
        address to,
        uint256 /* value */
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, 0);
    }
}
