// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleSharedInvariantStorage} from "./RuleSharedInvariantStorage.sol";

/**
 * @title RuleChainlinkPoRInvariantStorage — constants, events and errors for the Chainlink
 * Proof of Reserve rule.
 */
abstract contract RuleChainlinkPoRInvariantStorage is RuleSharedInvariantStorage {
    /* ============ Constants ============ */

    /**
     * @notice Upper bound accepted for a data feed's `decimals()` value.
     * @dev Chainlink feeds report 8 or 18 decimals. The bound keeps `10 ** (feedDecimals -
     * tokenDecimals)` inside `uint256` so the read path can never revert on exponentiation.
     */
    uint8 public constant MAX_FEED_DECIMALS = 36;

    /**
     * @notice Upper bound accepted for the protected token's `decimals()` value.
     * @dev `0` is a valid lower bound: CMTAT equity tokens commonly report 0 decimals.
     */
    uint8 public constant MAX_TOKEN_DECIMALS = 18;

    /* ============ String messages ============ */

    /**
     * @notice Restriction message returned when the mint is not backed by the reported reserves.
     */
    string constant TEXT_RESERVES_EXCEEDED = "Mint would exceed the proof of reserve backing";
    /**
     * @notice Restriction message returned when the reserve data is older than the staleness threshold.
     */
    string constant TEXT_RESERVES_FEED_STALE = "Proof of reserve data is stale";
    /**
     * @notice Restriction message returned when the feed answered but the answer is unusable.
     */
    string constant TEXT_RESERVES_ANSWER_INVALID = "Proof of reserve answer is invalid";
    /**
     * @notice Restriction message returned when the feed could not be read at all.
     */
    string constant TEXT_RESERVES_FEED_UNAVAILABLE = "Proof of reserve feed is unavailable";
    /**
     * @notice Restriction message returned when the token's total supply cannot be read.
     */
    string constant TEXT_TOTAL_SUPPLY_UNAVAILABLE = "Token total supply is unavailable";

    /* ============ Restriction codes ============ */

    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the new total supply would exceed the backed supply.
     */
    uint8 public constant CODE_RESERVES_EXCEEDED = 75;
    /**
     * @notice Restriction code returned when the feed has not been updated within the staleness threshold.
     */
    uint8 public constant CODE_RESERVES_FEED_STALE = 76;
    /**
     * @notice Restriction code returned when the feed responded but the answer cannot be used:
     * a negative reserve, an incomplete round (`updatedAt == 0`), or a round stamped in the future.
     * @dev Distinct from {CODE_RESERVES_FEED_UNAVAILABLE}: here a round *was* returned, so the feed
     * is reachable and the problem is the data. An operator seeing this checks whether the
     * configured address is really a Proof of Reserve feed, or waits for the round to complete.
     * @dev A future `updatedAt` is rejected here, NOT as staleness: `maxStalenessSeconds == 0` disables
     * freshness checking, and a forged timestamp must not become acceptable because an operator chose
     * not to police staleness.
     */
    uint8 public constant CODE_RESERVES_ANSWER_INVALID = 77;
    /**
     * @notice Restriction code returned when `tokenContract.totalSupply()` reverts or the token has
     * lost its code, so the current supply cannot be established.
     * @dev Fail-closed: without a supply figure the backing cannot be verified, so the mint is
     * blocked rather than assumed safe.
     */
    uint8 public constant CODE_TOTAL_SUPPLY_UNAVAILABLE = 78;
    /**
     * @notice Restriction code returned when no usable response could be obtained from the feed at
     * all: `decimals()` or `latestRoundData()` reverted, or the feed reports more than
     * {MAX_FEED_DECIMALS}.
     * @dev Distinct from {CODE_RESERVES_ANSWER_INVALID}: there is no answer to judge. An operator
     * seeing this checks feed liveness and whether the address is a compatible aggregator.
     */
    uint8 public constant CODE_RESERVES_FEED_UNAVAILABLE = 79;

    /* ============ Events ============ */

    /**
     * @notice Emitted when the Proof of Reserve data feed is set or replaced.
     * @param newReservesFeed Address of the newly configured data feed.
     * @param feedDecimals Decimals reported by that feed, cached at configuration time.
     */
    event ReservesFeedUpdated(address indexed newReservesFeed, uint8 feedDecimals);
    /**
     * @notice Emitted when the protected token or its decimals are updated.
     * @param newTokenContract Address of the token whose `totalSupply` is checked.
     * @param newTokenDecimals Decimals used to scale the reserve value.
     */
    event TokenMetadataUpdated(address indexed newTokenContract, uint8 newTokenDecimals);
    /**
     * @notice Emitted when the staleness threshold is updated.
     * @param newMaxStalenessSeconds New maximum accepted age of the reserve data, in seconds; 0 disables the check.
     */
    event MaxStalenessSecondsUpdated(uint256 newMaxStalenessSeconds);

    /* ============ Errors ============ */

    error RuleChainlinkPoR_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleChainlinkPoR_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
    error RuleChainlinkPoR_FeedAddressZeroNotAllowed();
    error RuleChainlinkPoR_FeedIsNotAContract(address feed);
    error RuleChainlinkPoR_FeedDecimalsUnavailable(address feed);
    error RuleChainlinkPoR_FeedDecimalsTooLarge(uint8 feedDecimals);
    error RuleChainlinkPoR_TokenAddressZeroNotAllowed();
    error RuleChainlinkPoR_TokenIsNotAContract(address token);
    error RuleChainlinkPoR_TokenTotalSupplyUnavailable(address token);
    error RuleChainlinkPoR_InvalidTokenDecimals(uint8 tokenDecimals);
    error RuleChainlinkPoR_TokenDecimalsMismatch(uint8 provided, uint8 onChain);
}
