// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleChainlinkPoRInvariantStorage} from "../invariant/RuleChainlinkPoRInvariantStorage.sol";
import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {AggregatorV3Interface} from "../../../interfaces/AggregatorV3Interface.sol";
import {IDecimals} from "../../../interfaces/IDecimals.sol";
import {ITotalSupply} from "../../../interfaces/ITotalSupply.sol";
import {TokenSupplyReader} from "./TokenSupplyReader.sol";

/**
 * @title ChainlinkPoRFeedManager
 * @notice Configuration and reading of a Chainlink Proof of Reserve feed: which feed, which token it
 * backs, how stale an answer may be, and how to scale it into token units.
 *
 * @dev Declares **no constructor** and does not depend on **ERC-1404**, so the inheriting rule
 * decides when configuration happens (constructor or initializer) and owns the code-to-message
 * mapping; {_maxBackedSupply} returns a plain `uint8` describing why an answer is unusable.
 *
 * @dev The feed's `decimals()` is read **live on every check, never cached**. Caching saves one call
 * but lets a feed that changes decimals mis-scale reserves by `10 ** delta` with no on-chain signal
 * -- in the overstating direction that silently authorises unbacked minting.
 *
 * @dev {_maxBackedSupply} must never revert, because the rule calls it from MUST-NOT-revert views,
 * so every feed interaction is `try/catch`-wrapped. That is only safe because the setters require
 * both the feed and the token to have code and EIP-6780 makes it permanent: a `try` to a codeless
 * address reverts *uncatchably*. Assumes a Cancun-or-later chain.
 */
abstract contract ChainlinkPoRFeedManager is TokenSupplyReader, RuleChainlinkPoRInvariantStorage {
    /**
     * @notice The Proof of Reserve data feed consulted before every mint.
     */
    AggregatorV3Interface public reservesFeed;
    /**
     * @dev tokenContract is trusted to return a correct totalSupply.
     */
    ITotalSupply public tokenContract;
    /**
     * @notice Decimals of the protected token, used to scale the reserve answer.
     */
    uint8 public tokenDecimals;
    /**
     * @notice Maximum accepted age of the reserve data, in seconds; 0 disables the staleness check.
     */
    uint256 public maxStalenessSeconds;

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyChainlinkPoRManager() {
        _authorizeChainlinkPoRManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the Proof of Reserve data feed and caches its decimals.
     * @dev The feed must be a contract whose `decimals()` call succeeds and reports at most
     * {MAX_FEED_DECIMALS}; both are validated here so the read path stays revert-free.
     * @param newReservesFeed The new data feed.
     */
    function setReservesFeed(AggregatorV3Interface newReservesFeed) public virtual onlyChainlinkPoRManager {
        _setReservesFeed(newReservesFeed);
    }

    /**
     * @notice Sets the protected token and the decimals used to scale the reserve answer.
     * @param newTokenContract The new token contract; must not be the zero address.
     * @param newTokenDecimals The token decimals; must be at most {MAX_TOKEN_DECIMALS} and, when the
     * token exposes `decimals()`, must match it. `0` is valid and common for CMTAT equity tokens.
     */
    function setTokenMetadata(address newTokenContract, uint8 newTokenDecimals) public virtual onlyChainlinkPoRManager {
        _setTokenMetadata(newTokenContract, newTokenDecimals);
    }

    /**
     * @notice Sets the maximum accepted age of the reserve data.
     * @param newMaxStalenessSeconds The new threshold in seconds; 0 disables the staleness check.
     */
    function setMaxStalenessSeconds(uint256 newMaxStalenessSeconds) public virtual onlyChainlinkPoRManager {
        _setMaxStalenessSeconds(newMaxStalenessSeconds);
    }

    /**
     * @notice Returns the decimals currently reported by {reservesFeed}.
     * @dev Read live from the feed rather than from storage, so it always agrees with what the
     * restriction checks use. Unlike the ERC-1404 views this getter is allowed to revert: it
     * forwards whatever the feed does, which is the honest answer for a diagnostic accessor.
     * @return The feed's current decimals.
     */
    function feedDecimals() public view virtual returns (uint8) {
        return reservesFeed.decimals();
    }

    /**
     * @notice Returns the supply currently backed by the reserves, i.e. the maximum total supply a
     * mint may reach. This is the reported reserves scaled into token units, with no margin applied.
     * @dev Mirrors what the rule's restriction check computes, so integrators can preview the limit
     * without simulating a mint. Never reverts.
     * @return restrictionCode `0` when the feed answer is usable, otherwise the restriction code
     * that a mint would return.
     * @return backedSupply The backed supply expressed in token units; meaningless when
     * `restrictionCode` is non-zero.
     */
    function maxBackedSupply() public view virtual returns (uint8 restrictionCode, uint256 backedSupply) {
        return _maxBackedSupply();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stores the data feed and emits {ReservesFeedUpdated}.
     * @dev The feed's `decimals()` is validated here so a misconfigured feed is rejected up front
     * rather than silently blocking every mint later, but the value is deliberately NOT cached --
     * {_maxBackedSupply} re-reads it on every check. The emitted decimals are informational: they
     * record what the feed reported at configuration time.
     * @param newReservesFeed The new data feed.
     */
    function _setReservesFeed(AggregatorV3Interface newReservesFeed) internal virtual {
        address feed = address(newReservesFeed);
        require(feed != address(0), RuleChainlinkPoR_FeedAddressZeroNotAllowed());
        require(feed.code.length != 0, RuleChainlinkPoR_FeedIsNotAContract(feed));
        uint8 newFeedDecimals;
        try newReservesFeed.decimals() returns (uint8 decimals_) {
            newFeedDecimals = decimals_;
        } catch {
            revert RuleChainlinkPoR_FeedDecimalsUnavailable(feed);
        }
        require(newFeedDecimals <= MAX_FEED_DECIMALS, RuleChainlinkPoR_FeedDecimalsTooLarge(newFeedDecimals));
        reservesFeed = newReservesFeed;
        emit ReservesFeedUpdated(feed, newFeedDecimals);
    }

    /**
     * @notice Stores the protected token and its decimals and emits {TokenMetadataUpdated}.
     * @dev When the token exposes `decimals()`, the provided value must match it; otherwise the
     * provided value is used as-is. WARNING: an incorrect value for a token that does not expose
     * `decimals()` skews the reserve comparison in either direction.
     * @param newTokenContract The new token contract.
     * @param newTokenDecimals The token decimals.
     */
    function _setTokenMetadata(address newTokenContract, uint8 newTokenDecimals) internal virtual {
        require(newTokenContract != address(0), RuleChainlinkPoR_TokenAddressZeroNotAllowed());
        // Explicit, rather than relying on the uncatchable extcodesize revert that the `decimals()`
        // probe below happens to produce for a codeless address: that is compiler behaviour, not a
        // check, and it would vanish if the probe were ever rewritten as a low-level staticcall.
        require(newTokenContract.code.length != 0, RuleChainlinkPoR_TokenIsNotAContract(newTokenContract));
        require(newTokenDecimals <= MAX_TOKEN_DECIMALS, RuleChainlinkPoR_InvalidTokenDecimals(newTokenDecimals));
        try IDecimals(newTokenContract).decimals() returns (uint8 onChainDecimals) {
            require(
                onChainDecimals == newTokenDecimals,
                RuleChainlinkPoR_TokenDecimalsMismatch(newTokenDecimals, onChainDecimals)
            );
        } catch {
            // The token does not expose `decimals()`; the provided value is used as-is.
        }
        // `totalSupply()` is mandatory, unlike `decimals()`: the restriction check cannot work
        // without it. Probing here turns a silent read-path failure into a configuration error.
        require(
            _probeTotalSupplyCallable(newTokenContract), RuleChainlinkPoR_TokenTotalSupplyUnavailable(newTokenContract)
        );
        tokenContract = ITotalSupply(newTokenContract);
        tokenDecimals = newTokenDecimals;
        emit TokenMetadataUpdated(newTokenContract, newTokenDecimals);
    }

    /**
     * @notice Stores the staleness threshold and emits {MaxStalenessSecondsUpdated}.
     * @param newMaxStalenessSeconds The new threshold in seconds; 0 disables the check.
     */
    function _setMaxStalenessSeconds(uint256 newMaxStalenessSeconds) internal virtual {
        maxStalenessSeconds = newMaxStalenessSeconds;
        emit MaxStalenessSecondsUpdated(newMaxStalenessSeconds);
    }

    /**
     * @notice Authorization hook invoked before any configuration change.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeChainlinkPoRManager() internal view virtual;

    /**
     * @notice Reads the feed and derives the supply currently backed by the reserves.
     * @dev Never reverts: the feed address is code-checked and the call is wrapped in `try/catch`.
     * @return restrictionCode `0` when the answer is usable, otherwise the reason it is not.
     * @return backedSupply The backed supply in token units; `0` when `restrictionCode` is non-zero.
     */
    function _maxBackedSupply() internal view virtual returns (uint8 restrictionCode, uint256 backedSupply) {
        AggregatorV3Interface feed = reservesFeed;
        // Read live, never cached: see the contract-level note on why the extra call is worth it.
        // No code-length guard: `_setReservesFeed` requires code and EIP-6780 makes that permanent.
        uint8 currentFeedDecimals;
        try feed.decimals() returns (uint8 decimals_) {
            currentFeedDecimals = decimals_;
        } catch {
            return (CODE_RESERVES_FEED_UNAVAILABLE, 0);
        }
        // Re-checked at read time, not just at configuration: a feed that raised its decimals past
        // the bound would otherwise overflow the scaling exponent and revert this view.
        if (currentFeedDecimals > MAX_FEED_DECIMALS) {
            return (CODE_RESERVES_FEED_UNAVAILABLE, 0);
        }
        try feed.latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
            // Three malformed answers, not stale ones: a negative reserve is meaningless, `updatedAt == 0`
            // marks a round that never completed, and a round stamped in the FUTURE cannot have been written
            // by an aggregator on this chain. Rejecting the future stamp here rather than as a staleness case
            // is deliberate -- `maxStalenessSeconds == 0` disables freshness checking, and a forged timestamp
            // must not become acceptable because an operator chose not to police staleness.
            if (answer < 0 || updatedAt == 0 || updatedAt > block.timestamp) {
                return (CODE_RESERVES_ANSWER_INVALID, 0);
            }
            uint256 staleness = maxStalenessSeconds;
            // `updatedAt <= block.timestamp` is guaranteed above, so the subtraction cannot underflow.
            if (staleness != 0 && block.timestamp - updatedAt > staleness) {
                return (CODE_RESERVES_FEED_STALE, 0);
            }
            // `answer >= 0` was just checked, so the cast to uint256 preserves the value.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint256 backed = _scaleReserve(uint256(answer), currentFeedDecimals);
            return (uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK), backed);
        } catch {
            return (CODE_RESERVES_FEED_UNAVAILABLE, 0);
        }
    }

    /**
     * @inheritdoc TokenSupplyReader
     */
    function _supplyToken() internal view virtual override returns (ITotalSupply) {
        return tokenContract;
    }

    /**
     * @notice Converts a reserve answer from the feed's decimals to the token's decimals.
     * @dev Saturates at `type(uint256).max` instead of overflowing: this function is on a
     * MUST-NOT-revert read path, and a reserve that large backs any representable supply anyway.
     * Scaling down truncates, which rounds the backed supply in the conservative direction.
     * @param answer The raw feed answer, expressed with `from` decimals.
     * @param from The feed's decimals, as read live for this check.
     * @return The reserve expressed with {tokenDecimals} decimals.
     */
    function _scaleReserve(uint256 answer, uint8 from) internal view virtual returns (uint256) {
        uint8 to = tokenDecimals;
        if (to == from) {
            return answer;
        }
        if (to > from) {
            // to <= MAX_TOKEN_DECIMALS, so the factor is at most 10 ** 18.
            uint256 factor = 10 ** uint256(to - from);
            if (answer > type(uint256).max / factor) {
                return type(uint256).max;
            }
            return answer * factor;
        }
        // `from` was bounded by MAX_FEED_DECIMALS above, so the divisor cannot overflow.
        return answer / (10 ** uint256(from - to));
    }
}
