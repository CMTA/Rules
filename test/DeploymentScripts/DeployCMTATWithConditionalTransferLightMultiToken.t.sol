// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {
    DeployCMTATWithConditionalTransferLightMultiToken
} from "script/DeployCMTATWithConditionalTransferLightMultiToken.s.sol";

contract DeployCMTATWithConditionalTransferLightMultiTokenTest is Test {
    address constant ADMIN = address(0xA11CE);
    address constant INVESTOR = address(0xB0B);
    address constant OTHER = address(0xCAFE);

    DeployCMTATWithConditionalTransferLightMultiToken script;
    CMTATStandardStandalone token;
    RuleConditionalTransferLightMultiToken rule;

    function setUp() public {
        script = new DeployCMTATWithConditionalTransferLightMultiToken();
        (token, rule) = script.deploy(ADMIN, address(script), address(0));
    }

    function testRuleIsSetOnTheTokenAndBoundToIt() public view {
        assertEq(address(token.ruleEngine()), address(rule));
        assertTrue(rule.isTokenBound(address(token)));
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
        (CMTATStandardStandalone t2, RuleConditionalTransferLightMultiToken r2) =
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
        uint8 code = rule.CODE_TRANSFER_REQUEST_NOT_APPROVED();
        assertEq(rule.detectTransferRestrictionForToken(address(token), INVESTOR, OTHER, 10), code);
        assertEq(token.detectTransferRestriction(INVESTOR, OTHER, 10), code);

        vm.prank(INVESTOR);
        vm.expectRevert();
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 10);
    }

    function testApprovedTransferPassesAndConsumesTheApproval() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);

        vm.prank(ADMIN);
        rule.approveTransfer(address(token), INVESTOR, OTHER, 10);
        assertEq(rule.detectTransferRestrictionForToken(address(token), INVESTOR, OTHER, 10), 0);
        // Through the token, msg.sender at the rule is the token, so the plain view agrees.
        assertEq(token.detectTransferRestriction(INVESTOR, OTHER, 10), 0);
        // Called directly by anyone else, the plain view is caller-dependent and answers 46.
        assertEq(rule.detectTransferRestriction(INVESTOR, OTHER, 10), rule.CODE_TRANSFER_REQUEST_NOT_APPROVED());

        vm.prank(INVESTOR);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 10);
        assertEq(token.balanceOf(OTHER), 10);
        assertEq(rule.approvedCount(address(token), INVESTOR, OTHER, 10), 0);
    }
}
