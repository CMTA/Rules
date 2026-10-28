// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";

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

    /// @notice Code 46 is shared by both conditional-transfer rules. The engine answers its message from the first
    /// rule claiming the code, so both rules must give the same text, whichever is added first.
    function testSharedCode46HasOneMessageWhicheverRuleAnswers() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLight light = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        RuleEngine lightFirst = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        lightFirst.addRule(light);
        lightFirst.addRule(rule);
        vm.stopPrank();

        string memory expected = "ConditionalTransfer: The request is not approved";
        assertEq(light.messageForTransferRestriction(CODE_TRANSFER_REQUEST_NOT_APPROVED), expected);
        assertEq(rule.messageForTransferRestriction(CODE_TRANSFER_REQUEST_NOT_APPROVED), expected);
        assertEq(lightFirst.messageForTransferRestriction(CODE_TRANSFER_REQUEST_NOT_APPROVED), expected);
        // `sharedRuleEngine` holds only the multi-token rule, so it is the one answering there.
        assertEq(sharedRuleEngine.messageForTransferRestriction(CODE_TRANSFER_REQUEST_NOT_APPROVED), expected);
    }
}
