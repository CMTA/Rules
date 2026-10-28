// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {DeployCMTATWithChainlinkPoR} from "script/DeployCMTATWithChainlinkPoR.s.sol";

/**
 * The mock-feed fallback in run() is not covered here: it only runs under a broadcast, which a test
 * cannot enter. The `forge script` dry run exercises it.
 */
contract DeployCMTATWithChainlinkPoRTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);
    address constant OTHER = address(3);
    uint256 constant RESERVES = 1_000;
    uint256 constant STALENESS = 1 days;

    /// RuleChainlinkPoRInvariantStorage codes
    uint8 constant CODE_RESERVES_EXCEEDED = 75;
    uint8 constant CODE_RESERVES_FEED_STALE = 76;

    DeployCMTATWithChainlinkPoR script;
    AggregatorV3Mock feed;
    CMTATStandardStandalone token;
    RuleChainlinkPoR rule;

    function setUp() public {
        vm.warp(1_700_000_000);
        script = new DeployCMTATWithChainlinkPoR();
        // The default token has 0 decimals; a 0-decimal feed reports reserves in whole tokens.
        feed = new AggregatorV3Mock(0, int256(RESERVES));
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast.
        (token, rule) =
            script.deploy(ADMIN, address(script), address(0), AggregatorV3Interface(address(feed)), STALENESS);
    }

    function testSetsTheRuleOnTheTokenAndPointsItAtTheTokenAndFeed() public view {
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(address(rule.tokenContract()), address(token));
        assertEq(address(rule.reservesFeed()), address(feed));
        assertEq(rule.tokenDecimals(), token.decimals());
        assertEq(rule.maxStalenessSeconds(), STALENESS);
    }

    function testHandsAdminRoleToAdmin() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function testDeployerRetainsNoAdminRole() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testAdminEqualToDeployerKeepsTheRole() public {
        (CMTATStandardStandalone t2,) =
            script.deploy(address(script), address(script), address(0), AggregatorV3Interface(address(feed)), STALENESS);
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testMintWithinReservesSucceeds() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, RESERVES);
        assertEq(token.totalSupply(), RESERVES);
    }

    function testMintAboveReservesIsRejected() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, RESERVES);

        assertEq(token.detectTransferRestriction(address(0), INVESTOR, 1), CODE_RESERVES_EXCEEDED);
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(INVESTOR, 1);
    }

    function testStaleFeedBlocksMintsButNotTransfers() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 10);
        vm.warp(block.timestamp + STALENESS + 1);

        assertEq(token.detectTransferRestriction(address(0), INVESTOR, 1), CODE_RESERVES_FEED_STALE);
        vm.prank(INVESTOR);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 10);
        assertEq(token.balanceOf(OTHER), 10);
    }

    function testDeployRejectsAFeedWithoutCode() public {
        vm.expectRevert();
        script.deploy(ADMIN, address(script), address(0), AggregatorV3Interface(address(0xFEED)), STALENESS);
    }
}
