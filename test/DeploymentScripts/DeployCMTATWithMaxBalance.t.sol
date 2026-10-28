// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleMaxBalance} from "src/rules/validation/deployment/RuleMaxBalance.sol";
import {DeployCMTATWithMaxBalance} from "script/DeployCMTATWithMaxBalance.s.sol";

contract DeployCMTATWithMaxBalanceTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);
    address constant OTHER = address(3);
    address constant TREASURY = address(0xBEEF);
    uint256 constant CAP = 1_000;

    /// RuleMaxBalanceInvariantStorage.CODE_MAX_BALANCE_EXCEEDED
    uint8 constant CODE_MAX_BALANCE_EXCEEDED = 82;

    DeployCMTATWithMaxBalance script;
    CMTATStandardStandalone token;
    RuleMaxBalance rule;

    function setUp() public {
        script = new DeployCMTATWithMaxBalance();
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast.
        (token, rule) = script.deploy(ADMIN, address(script), address(0), CAP);
    }

    function testSetsTheRuleOnTheTokenAndPointsItAtTheToken() public view {
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(address(rule.balanceToken()), address(token));
        assertEq(rule.maxBalance(), CAP);
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
        (CMTATStandardStandalone t2,) = script.deploy(address(script), address(script), address(0), CAP);
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testMintUpToTheCapSucceeds() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, CAP);
        assertEq(token.balanceOf(INVESTOR), CAP);
    }

    function testMintAboveTheCapIsRejected() public {
        assertEq(token.detectTransferRestriction(address(0), INVESTOR, CAP + 1), CODE_MAX_BALANCE_EXCEEDED);
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(INVESTOR, CAP + 1);
    }

    function testTransferPushingReceiverOverTheCapIsRejected() public {
        vm.startPrank(ADMIN);
        token.mint(INVESTOR, CAP);
        token.mint(OTHER, 1);
        vm.stopPrank();

        assertEq(token.detectTransferRestriction(OTHER, INVESTOR, 1), CODE_MAX_BALANCE_EXCEEDED);
        vm.prank(OTHER);
        vm.expectRevert();
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(INVESTOR, 1);
    }

    function testExemptAddressMayExceedTheCap() public {
        vm.prank(ADMIN);
        rule.addExemptAddress(TREASURY);
        vm.prank(ADMIN);
        token.mint(TREASURY, CAP * 10);
        assertEq(token.balanceOf(TREASURY), CAP * 10);
    }
}
