// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "../rules/interfaces/AggregatorV3Interface.sol";

/**
 * @title AggregatorV3Mock — configurable Chainlink data feed test double.
 * @notice Reports a settable answer, timestamp and decimals, and can be told to revert on
 * `decimals()` or `latestRoundData()` so the failure paths of the Proof of Reserve rule can be exercised.
 */
contract AggregatorV3Mock is AggregatorV3Interface {
    /**
     * @notice Decimals reported by the feed.
     */
    uint8 private _decimals;
    /**
     * @notice The reserve answer returned by `latestRoundData`.
     */
    int256 private _answer;
    /**
     * @notice Round identifier, bumped on every {setAnswer}.
     */
    uint80 private _roundId;
    /**
     * @notice Timestamp reported as `updatedAt`; 0 simulates an incomplete round.
     */
    uint256 private _updatedAt;
    /**
     * @notice When true, `decimals()` reverts.
     */
    bool private _revertOnDecimals;
    /**
     * @notice When true, `latestRoundData()` reverts.
     */
    bool private _revertOnLatestRoundData;

    /**
     * @notice Deploys the mock with an initial answer and decimals.
     * @param decimals_ Decimals reported by the feed.
     * @param answer_ Initial reserve answer.
     */
    constructor(uint8 decimals_, int256 answer_) {
        _decimals = decimals_;
        _answer = answer_;
        _roundId = 1;
        _updatedAt = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the answer reported by the feed and refreshes `updatedAt` to the current block.
     * @param answer_ The new answer.
     */
    function setAnswer(int256 answer_) external {
        _answer = answer_;
        _roundId += 1;
        _updatedAt = block.timestamp;
    }

    /**
     * @notice Sets the timestamp reported as `updatedAt`, without touching the answer.
     * @param updatedAt_ The new timestamp; 0 simulates an incomplete round.
     */
    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;
    }

    /**
     * @notice Sets the decimals reported by the feed.
     * @param decimals_ The new decimals.
     */
    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }

    /**
     * @notice Makes `decimals()` revert, simulating a feed that does not honour the interface.
     * @param shouldRevert True to revert on the next `decimals()` call.
     */
    function setRevertOnDecimals(bool shouldRevert) external {
        _revertOnDecimals = shouldRevert;
    }

    /**
     * @notice Makes `latestRoundData()` revert, simulating an unavailable feed.
     * @param shouldRevert True to revert on the next `latestRoundData()` call.
     */
    function setRevertOnLatestRoundData(bool shouldRevert) external {
        _revertOnLatestRoundData = shouldRevert;
    }

    /**
     * @inheritdoc AggregatorV3Interface
     */
    function decimals() external view override returns (uint8) {
        require(!_revertOnDecimals, AggregatorV3Mock_Unavailable());
        return _decimals;
    }

    /**
     * @inheritdoc AggregatorV3Interface
     */
    function description() external pure override returns (string memory) {
        return "AggregatorV3Mock";
    }

    /**
     * @inheritdoc AggregatorV3Interface
     */
    function version() external pure override returns (uint256) {
        return 3;
    }

    /**
     * @inheritdoc AggregatorV3Interface
     */
    function getRoundData(uint80 roundId_)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (roundId_, _answer, _updatedAt, _updatedAt, roundId_);
    }

    /**
     * @inheritdoc AggregatorV3Interface
     */
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        require(!_revertOnLatestRoundData, AggregatorV3Mock_Unavailable());
        return (_roundId, _answer, _updatedAt, _updatedAt, _roundId);
    }

    error AggregatorV3Mock_Unavailable();
}
