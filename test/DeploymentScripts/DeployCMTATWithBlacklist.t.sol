// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {DeployCMTATWithBlacklist} from "script/DeployCMTATWithBlacklist.s.sol";

contract DeployCMTATWithBlacklistTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);

    DeployCMTATWithBlacklist script;
    CMTATStandardStandalone token;
    RuleBlacklist rule;

    function setUp() public {
        script = new DeployCMTATWithBlacklist();
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast, so
        // it makes the wiring calls itself.
        (token, rule) = script.deploy(ADMIN, address(0));
    }

    function testBindsTheRuleToTheToken() public view {
        assertEq(address(token.ruleEngine()), address(rule));
    }

    /// The hand-over is the security-critical step and used to be untested (CLAUDE_ANALYSIS_SCRIPT.md S-10).
    function testHandsAdminRoleToAdmin() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function testDeployerRetainsNoAdminRole() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testRuleAdminIsAdmin() public view {
        assertTrue(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    /// A blacklist leaves mint open, so the token is issuable straight out of the script.
    function testTokenCanBeMinted() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 100);
    }

    function testBlacklistedAddressIsBlocked() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        vm.prank(ADMIN);
        rule.addAddress(INVESTOR);

        vm.prank(INVESTOR);
        vm.expectRevert();
        token.transfer(ADMIN, 1);
    }
}
