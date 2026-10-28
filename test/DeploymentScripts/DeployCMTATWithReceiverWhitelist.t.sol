// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {DeployCMTATWithReceiverWhitelist} from "script/DeployCMTATWithReceiverWhitelist.s.sol";

contract DeployCMTATWithReceiverWhitelistTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);
    address constant OTHER = address(3);

    /// RuleReceiverWhitelistInvariantStorage.CODE_ADDRESS_RECEIVER_NOT_WHITELISTED
    uint8 constant CODE_ADDRESS_RECEIVER_NOT_WHITELISTED = 90;

    DeployCMTATWithReceiverWhitelist script;
    CMTATStandardStandalone token;
    RuleReceiverWhitelist rule;

    function setUp() public {
        script = new DeployCMTATWithReceiverWhitelist();
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast.
        (token, rule) = script.deploy(ADMIN, address(0));
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
        (CMTATStandardStandalone t2, RuleReceiverWhitelist r2) = script.deploy(address(script), address(0));
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
        assertTrue(r2.hasRole(r2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testMintToAListedInvestorSucceeds() public {
        vm.prank(ADMIN);
        rule.addAddress(INVESTOR);

        assertEq(token.detectTransferRestriction(address(0), INVESTOR, 100), 0);
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 100);
    }

    function testMintToAnUnlistedAddressIsRejected() public {
        assertEq(token.detectTransferRestriction(address(0), OTHER, 100), CODE_ADDRESS_RECEIVER_NOT_WHITELISTED);
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(OTHER, 100);
    }

    function testTransferToAnUnlistedReceiverIsRejected() public {
        vm.prank(ADMIN);
        rule.addAddress(INVESTOR);
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);

        assertEq(token.detectTransferRestriction(INVESTOR, OTHER, 1), CODE_ADDRESS_RECEIVER_NOT_WHITELISTED);
        vm.prank(INVESTOR);
        vm.expectRevert();
        token.transfer(OTHER, 1);
    }

    /// The sender is never screened: a de-listed holder can still exit to a listed receiver.
    function testDelistedHolderCanStillExit() public {
        vm.startPrank(ADMIN);
        rule.addAddress(INVESTOR);
        rule.addAddress(OTHER);
        token.mint(INVESTOR, 100);
        rule.removeAddress(INVESTOR);
        vm.stopPrank();

        assertEq(token.detectTransferRestriction(INVESTOR, OTHER, 100), 0);
        vm.prank(INVESTOR);
        token.transfer(OTHER, 100);
        assertEq(token.balanceOf(OTHER), 100);
    }
}
