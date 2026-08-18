// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "../../interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoR} from "./RuleChainlinkPoR.sol";

/**
 * @title RuleChainlinkPoRERC3643
 * @notice {RuleChainlinkPoR} for **ERC-3643 tokens only**. Identical reserve logic; the sole
 * difference is WHEN the token reports the mint.
 *
 * @dev **Use this variant if and only if the token calls compliance AFTER it has moved the value.**
 * ERC-3643 / T-REX does: `mint` runs `_mint(_to, _amount)` and only then
 * `_tokenCompliance.created(_to, _amount)`, so by the time this rule is consulted `totalSupply()`
 * already includes the new tokens. CMTAT does the opposite -- it calls the rule first -- and must use
 * plain {RuleChainlinkPoR}.
 *
 * @dev **Picking the wrong variant breaks the cap in one direction or the other, silently.** On an
 * ERC-3643 token the stock rule counts the minted amount twice and rejects mints that are fully
 * backed; on a CMTAT token this variant ignores the pending amount and would authorise a mint that
 * overshoots the reserves. Neither shows up as a revert at configuration time.
 *
 * @dev Only the WRITE path is re-phased. The ERC-1404 / ERC-3643 read views
 * (`detectTransferRestriction`, `canTransfer`, `maxBackedSupply`) still project the pending amount,
 * because a pre-flight query always runs before the movement on either kind of token -- ERC-3643
 * itself calls `canTransfer` before `_transfer`. Re-phasing them too would make the pre-flight answer
 * disagree with enforcement.
 *
 * @dev Mint is the only gated operation, so the ERC-3643 paths that matter are `mint` (which reports
 * through `created`) and `forcedMint` where present. Transfers and burns are never blocked by this
 * rule, on either variant.
 */
contract RuleChainlinkPoRERC3643 is RuleChainlinkPoR {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address that receives the default admin role.
     * @param tokenContract_ Token contract that exposes totalSupply (must be non-zero).
     * @param tokenDecimals_ Decimals of that token (0 to 18, checked against `decimals()` when exposed).
     * @param reservesFeed_ Proof of Reserve data feed implementing `AggregatorV3Interface`.
     * @param maxStalenessSeconds_ Initial staleness threshold in seconds; 0 disables the check.
     */
    constructor(
        address admin,
        address tokenContract_,
        uint8 tokenDecimals_,
        AggregatorV3Interface reservesFeed_,
        uint256 maxStalenessSeconds_
    ) RuleChainlinkPoR(admin, tokenContract_, tokenDecimals_, reservesFeed_, maxStalenessSeconds_) {}

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
