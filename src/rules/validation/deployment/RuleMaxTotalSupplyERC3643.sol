// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleMaxTotalSupply} from "./RuleMaxTotalSupply.sol";

/**
 * @title RuleMaxTotalSupplyERC3643
 * @notice {RuleMaxTotalSupply} for **ERC-3643 tokens only**. Identical supply-cap logic; the sole
 * difference is WHEN the token reports the mint.
 *
 * @dev **Use this variant if and only if the token calls compliance AFTER it has moved the value.**
 * ERC-3643 / T-REX does: `mint` runs `_mint(_to, _amount)` and only then
 * `_tokenCompliance.created(_to, _amount)`, so by the time this rule is consulted `totalSupply()`
 * already includes the new tokens. CMTAT does the opposite -- it calls the rule first -- and must use
 * plain {RuleMaxTotalSupply}.
 *
 * @dev **Picking the wrong variant breaks the cap in one direction or the other, silently.** On an
 * ERC-3643 token the stock rule counts the minted amount twice and rejects mints that are within the
 * ceiling; on a CMTAT token this variant ignores the pending amount and would authorise a mint that
 * overshoots it. Neither shows up as a revert at configuration time.
 *
 * @dev Only the WRITE path is re-phased. The ERC-1404 / ERC-3643 read views still project the pending
 * amount, because a pre-flight query always runs before the movement -- ERC-3643 itself calls
 * `canTransfer(address(0), to, amount)` before `_mint`. Re-phasing them too would make the pre-flight
 * answer disagree with enforcement.
 *
 * @dev Composes with {RuleChainlinkPoRERC3643} exactly as the CMTAT pair does: the Proof-of-Reserve
 * rule has no margin parameter, so pair the two when a static ceiling is wanted alongside the
 * reserve-backed one. Behind a RuleEngine the first non-zero code wins, so rule order decides which
 * of `50` and `75` a rejection reports.
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
