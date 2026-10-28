// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title AggregatorV3Interface — Chainlink data feed read interface.
 * @notice Minimal local copy of the Chainlink `AggregatorV3Interface` used to read a
 * Proof of Reserve (PoR) data feed. It is redeclared here rather than imported so that
 * the library does not take a dependency on the Chainlink contracts package; the selectors
 * are identical to the canonical interface, so any Chainlink aggregator can be cast to it.
 * @dev Reference: https://docs.chain.link/data-feeds/api-reference
 */
interface AggregatorV3Interface {
    /**
     * @notice Number of decimals used by the values this feed reports.
     * @return The feed decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Human-readable description of the feed, e.g. "WBTC PoR".
     * @return The feed description.
     */
    function description() external view returns (string memory);

    /**
     * @notice Version number of the aggregator implementation.
     * @return The aggregator version.
     */
    function version() external view returns (uint256);

    /**
     * @notice Returns the data of a specific round.
     * @param _roundId Identifier of the round to read.
     * @return roundId The round identifier.
     * @return answer The reported value for that round.
     * @return startedAt Timestamp at which the round started.
     * @return updatedAt Timestamp at which the round was last updated.
     * @return answeredInRound Round identifier in which the answer was computed.
     */
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    /**
     * @notice Returns the data of the latest round.
     * @return roundId The round identifier.
     * @return answer The reported value for that round.
     * @return startedAt Timestamp at which the round started.
     * @return updatedAt Timestamp at which the round was last updated.
     * @return answeredInRound Round identifier in which the answer was computed.
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
