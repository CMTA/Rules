// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";

/**
 * @title RuleChainlinkPoR on CMTAT v3.0.0
 * @notice The v3.0.0 token reports 0 decimals; the feed reports 1,000 tokens of reserves with 8 decimals.
 */
abstract contract RuleChainlinkPoRV300Test is CMTATv300TestBase {
    uint256 constant STALENESS = 1 days;
    RuleChainlinkPoR internal rule;
    AggregatorV3Mock internal feed;

    function setUp() public {
        _deployToken();
        feed = new AggregatorV3Mock(8, 1000 * 1e8);
        rule = new RuleChainlinkPoR(
            DEFAULT_ADMIN_ADDRESS, address(token), 0, AggregatorV3Interface(address(feed)), STALENESS
        );
        _attach(address(rule));
        _mint(ADDRESS1, 600);
    }

    function testMintUpToTheReserves() public {
        _assertCode(ZERO_ADDRESS, ADDRESS2, 400, TRANSFER_OK);
        _mint(ADDRESS2, 400);
        assertEq(token.totalSupply(), 1000);
    }

    function testCannotMintAboveTheReserves() public {
        _assertCode(ZERO_ADDRESS, ADDRESS2, 401, CODE_RESERVES_EXCEEDED);
        vm.expectPartialRevert(RuleChainlinkPoR_InvalidTransfer.selector);
        _mint(ADDRESS2, 401);
    }

    function testStaleFeedBlocksMintsButNotTransfersOrBurns() public {
        vm.warp(block.timestamp + STALENESS + 1);
        _assertCode(ZERO_ADDRESS, ADDRESS2, 1, CODE_RESERVES_FEED_STALE);
        vm.expectPartialRevert(RuleChainlinkPoR_InvalidTransfer.selector);
        _mint(ADDRESS2, 1);
        _transfer(ADDRESS1, ADDRESS2, 10);
        _burn(ADDRESS1, 10);
        assertEq(token.totalSupply(), 590);
    }
}

contract RuleChainlinkPoRV300StandardDirectTest is RuleChainlinkPoRV300Test, V300StandardDirect {}

contract RuleChainlinkPoRV300StandardEngineTest is RuleChainlinkPoRV300Test, V300StandardEngine {}

contract RuleChainlinkPoRV300DebtDirectTest is RuleChainlinkPoRV300Test, V300DebtDirect {}

contract RuleChainlinkPoRV300DebtEngineTest is RuleChainlinkPoRV300Test, V300DebtEngine {}
