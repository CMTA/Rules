// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";
import {DeployCMTATWithConditionalTransferLight} from "script/DeployCMTATWithConditionalTransferLight.s.sol";

contract DeployCMTATWithConditionalTransferLightTest is Test {
    address constant ADMIN = address(0xA11CE);
    address constant INVESTOR = address(0xB0B);
    address constant OTHER = address(0xCAFE);

    DeployCMTATWithConditionalTransferLight script;
    CMTATStandardStandalone token;
    RuleConditionalTransferLight rule;

    function setUp() public {
        script = new DeployCMTATWithConditionalTransferLight();
        (token, rule) = script.deploy(ADMIN, address(script), address(0));
    }

    function testRuleIsSetOnTheTokenAndBoundToIt() public view {
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(rule.getTokenBound(), address(token));
    }

    function testHandsAdminRoleToAdminOnTokenAndRule() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function testDeployerRetainsNoAdminRole() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testAdminEqualToDeployerKeepsTheRole() public {
        (CMTATStandardStandalone t2, RuleConditionalTransferLight r2) =
            script.deploy(address(script), address(script), address(0));
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
        assertTrue(r2.hasRole(r2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testMintAndBurnNeedNoApproval() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        vm.prank(ADMIN);
        token.burn(INVESTOR, 10);
        assertEq(token.balanceOf(INVESTOR), 90);
    }

    function testUnapprovedTransferIsRejected() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        assertEq(token.detectTransferRestriction(INVESTOR, OTHER, 10), rule.CODE_TRANSFER_REQUEST_NOT_APPROVED());

        vm.prank(INVESTOR);
        vm.expectRevert();
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 10);
    }

    function testApprovedTransferPassesAndConsumesTheApproval() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);

        // The admin implicitly holds OPERATOR_ROLE.
        vm.prank(ADMIN);
        rule.approveTransfer(INVESTOR, OTHER, 10);
        assertEq(token.detectTransferRestriction(INVESTOR, OTHER, 10), 0);

        vm.prank(INVESTOR);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 10);
        assertEq(token.balanceOf(OTHER), 10);
        assertEq(rule.approvedCount(INVESTOR, OTHER, 10), 0);

        // The approval was single-use.
        vm.prank(INVESTOR);
        vm.expectRevert();
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 10);
    }

    function testApproveAndTransferIfAllowedWorksInDirectMode() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        vm.prank(INVESTOR);
        token.approve(address(rule), 10);

        vm.prank(ADMIN);
        rule.approveAndTransferIfAllowed(INVESTOR, OTHER, 10);
        assertEq(token.balanceOf(OTHER), 10);
    }
}
