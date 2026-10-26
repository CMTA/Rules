// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";

contract RuleConditionalTransferLightMultiTokenRuleEngineIntegrationTest is Test, HelperContract {
    RuleConditionalTransferLightMultiToken private rule;
    RuleEngine private sharedRuleEngine;

    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        sharedRuleEngine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);

        // In RuleEngine path, rule sees only msg.sender == RuleEngine.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(sharedRuleEngine));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS2);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        sharedRuleEngine.addRule(rule);
    }

    function testTokenScopedApprovalIsNotVisibleThroughSharedRuleEngineCallerContext() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);

        resUint8 = sharedRuleEngine.detectTransferRestriction(ADDRESS2, ADDRESS3, 10);
        assertEq(resUint8, CODE_TRANSFER_REQUEST_NOT_APPROVED);
    }

    function testRuleEngineScopedApprovalIsConsumableButNotTokenScoped() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(sharedRuleEngine), ADDRESS2, ADDRESS3, 10);

        resUint8 = sharedRuleEngine.detectTransferRestriction(ADDRESS2, ADDRESS3, 10);
        assertEq(resUint8, TRANSFER_OK);

        vm.prank(address(sharedRuleEngine));
        rule.transferred(ADDRESS2, ADDRESS3, 10);

        resUint8 = sharedRuleEngine.detectTransferRestriction(ADDRESS2, ADDRESS3, 10);
        assertEq(resUint8, CODE_TRANSFER_REQUEST_NOT_APPROVED);
    }
}
