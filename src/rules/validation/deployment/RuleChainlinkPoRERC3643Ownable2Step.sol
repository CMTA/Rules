// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "../../interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoROwnable2Step} from "./RuleChainlinkPoROwnable2Step.sol";

/**
 * @title RuleChainlinkPoRERC3643Ownable2Step
 * @notice {RuleChainlinkPoROwnable2Step} for **ERC-3643 tokens only**. Identical reserve logic; the sole difference is WHEN the
 * token reports the mint.
 *
 * @dev **Use this variant if and only if the token calls compliance AFTER it has moved the value.** ERC-3643 /
 * T-REX does: `mint` runs `_mint` and only then `_tokenCompliance.created`, so `totalSupply()` already includes
 * the new tokens. CMTAT calls the rule first and must use plain {RuleChainlinkPoROwnable2Step}.
 *
 * @dev **Picking the wrong variant breaks the cap silently, and nothing reverts at configuration time.** The
 * stock rule on ERC-3643 counts the minted amount twice and rejects mints that are within the reserves reported by the feed; this variant
 * on CMTAT ignores the pending amount and weakens enforcement.
 *
 * @dev Only the WRITE path is re-phased — the read views still project the pending amount, because ERC-3643
 * calls `canTransfer` before `_mint`.
 */
contract RuleChainlinkPoRERC3643Ownable2Step is RuleChainlinkPoROwnable2Step {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner Contract owner.
     * @param tokenContract_ Token contract that exposes totalSupply (must be non-zero).
     * @param tokenDecimals_ Decimals of that token (0 to 18, checked against `decimals()` when exposed).
     * @param reservesFeed_ Proof of Reserve data feed implementing `AggregatorV3Interface`.
     * @param maxStalenessSeconds_ Initial staleness threshold in seconds; 0 disables the check.
     */
    constructor(
        address owner,
        address tokenContract_,
        uint8 tokenDecimals_,
        AggregatorV3Interface reservesFeed_,
        uint256 maxStalenessSeconds_
    ) RuleChainlinkPoROwnable2Step(owner, tokenContract_, tokenDecimals_, reservesFeed_, maxStalenessSeconds_) {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enforcement for a token that reports the mint after performing it.
     * @dev Re-asks the standard check with nothing left to add: `totalSupply()` already includes the
     * minted amount, so the comparison reduces to "is the post-mint supply within the reserves".
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
