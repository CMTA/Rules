// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {DeployCMTATWithWhitelist} from "script/DeployCMTATWithWhitelist.s.sol";

contract DeployCMTATWithWhitelistTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);
    address constant OTHER = address(3);

    /// RuleWhitelistInvariantStorage.CODE_MINT_NOT_ALLOWED
    uint8 constant CODE_MINT_NOT_ALLOWED = 24;

    DeployCMTATWithWhitelist script;
    CMTATStandardStandalone token;
    RuleWhitelist rule;

    function setUp() public {
        script = new DeployCMTATWithWhitelist();
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast, so
        // it makes the wiring calls itself.
        (token, rule) = script.deploy(ADMIN, address(0), false, true);
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

    /**
     * The script used to hard-code `allowMintBurn = false`, which produced a token that could not be
     * issued at all: mint was rejected with code 24 even to a whitelisted investor
     * (CLAUDE_ANALYSIS_SCRIPT.md S-3). run() now passes true.
     */
    function testTokenCanBeMintedToAWhitelistedInvestor() public {
        vm.prank(ADMIN);
        rule.addAddress(INVESTOR);

        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);

        assertEq(token.balanceOf(INVESTOR), 100);
    }

    /// Pins the failure mode the old default caused, so a regression is legible rather than puzzling.
    function testMintIsRejectedWhenMintBurnIsNotAllowed() public {
        (CMTATStandardStandalone t2, RuleWhitelist r2) = script.deploy(ADMIN, address(0), false, false);

        vm.prank(ADMIN);
        r2.addAddress(INVESTOR);

        assertEq(r2.detectTransferRestriction(address(0), INVESTOR, 100), CODE_MINT_NOT_ALLOWED);

        vm.prank(ADMIN);
        vm.expectRevert();
        t2.mint(INVESTOR, 100);
    }

    function testTransferToNonWhitelistedAddressIsBlocked() public {
        vm.prank(ADMIN);
        rule.addAddress(INVESTOR);
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);

        vm.prank(INVESTOR);
        vm.expectRevert();
        token.transfer(OTHER, 1);
    }
}
