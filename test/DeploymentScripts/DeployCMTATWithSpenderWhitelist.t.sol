// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {DeployCMTATWithSpenderWhitelist} from "script/DeployCMTATWithSpenderWhitelist.s.sol";

contract DeployCMTATWithSpenderWhitelistTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);
    address constant OTHER = address(3);
    address constant SPENDER = address(0x5bE4D);
    address constant STRANGER = address(0x57A2);

    /// RuleSpenderWhitelistInvariantStorage.CODE_ADDRESS_SPENDER_NOT_WHITELISTED
    uint8 constant CODE_ADDRESS_SPENDER_NOT_WHITELISTED = 66;

    DeployCMTATWithSpenderWhitelist script;
    CMTATStandardStandalone token;
    RuleSpenderWhitelist rule;

    function setUp() public {
        script = new DeployCMTATWithSpenderWhitelist();
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast.
        (token, rule) = script.deploy(ADMIN, address(script), address(0));

        // Mints are not screened by this rule.
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        vm.prank(INVESTOR);
        token.approve(SPENDER, 100);
        vm.prank(INVESTOR);
        token.approve(STRANGER, 100);
    }

    function testSetsTheRuleOnTheToken() public view {
        assertEq(address(token.ruleEngine()), address(rule));
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
        (CMTATStandardStandalone t2, RuleSpenderWhitelist r2) =
            script.deploy(address(script), address(script), address(0));
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
        assertTrue(r2.hasRole(r2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testTransferFromByAListedSpenderSucceeds() public {
        vm.prank(ADMIN);
        rule.addAddress(SPENDER);

        assertEq(token.detectTransferRestrictionFrom(SPENDER, INVESTOR, OTHER, 10), 0);
        vm.prank(SPENDER);
        token.transferFrom(INVESTOR, OTHER, 10);
        assertEq(token.balanceOf(OTHER), 10);
    }

    function testTransferFromByAnUnlistedSpenderIsRejected() public {
        assertEq(
            token.detectTransferRestrictionFrom(STRANGER, INVESTOR, OTHER, 10), CODE_ADDRESS_SPENDER_NOT_WHITELISTED
        );
        vm.prank(STRANGER);
        vm.expectRevert();
        token.transferFrom(INVESTOR, OTHER, 10);
    }

    /// The rule acts only on transferFrom: a direct transfer between unlisted holders passes.
    function testDirectTransferIsNeverScreened() public {
        assertEq(token.detectTransferRestriction(INVESTOR, OTHER, 10), 0);
        vm.prank(INVESTOR);
        token.transfer(OTHER, 10);
        assertEq(token.balanceOf(OTHER), 10);
    }
}
