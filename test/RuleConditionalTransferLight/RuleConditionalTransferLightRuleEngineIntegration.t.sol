// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";

/**
 * @title Integration test between RuleEngine and RuleConditionalTransferLight
 */
contract RuleConditionalTransferLightRuleEngineIntegration is Test, HelperContract {
    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight = new RuleConditionalTransferLight(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);

        vm.prank(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);
        ruleConditionalTransferLight.bindToken(address(ruleEngineMock));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleConditionalTransferLight);
    }

    function testDetectRestrictionAndCanTransferWithoutApproval() public {
        uint256 amount = 10;
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_TRANSFER_REQUEST_NOT_APPROVED);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);
    }

    function testApproveAndConsumeMultipleTransfers() public {
        uint256 amount = 10;

        vm.prank(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);
        ruleConditionalTransferLight.approveTransfer(ADDRESS1, ADDRESS2, amount);
        vm.prank(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);
        ruleConditionalTransferLight.approveTransfer(ADDRESS1, ADDRESS2, amount);

        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);

        vm.prank(address(ruleEngineMock));
        ruleConditionalTransferLight.transferred(ADDRESS1, ADDRESS2, amount);
        vm.prank(address(ruleEngineMock));
        ruleConditionalTransferLight.transferred(ADDRESS1, ADDRESS2, amount);

        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_TRANSFER_REQUEST_NOT_APPROVED);

        vm.expectRevert(TransferNotApproved.selector);
        vm.prank(address(ruleEngineMock));
        ruleConditionalTransferLight.transferred(ADDRESS1, ADDRESS2, amount);
    }

    function testTransferredWithoutApprovalReverts() public {
        vm.expectRevert(TransferNotApproved.selector);
        vm.prank(address(ruleEngineMock));
        ruleConditionalTransferLight.transferred(ADDRESS1, ADDRESS2, 10);
    }

    function testCancelApproval() public {
        uint256 amount = 10;

        vm.prank(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);
        ruleConditionalTransferLight.approveTransfer(ADDRESS1, ADDRESS2, amount);
        vm.prank(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);
        ruleConditionalTransferLight.approveTransfer(ADDRESS1, ADDRESS2, amount);

        vm.prank(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);
        ruleConditionalTransferLight.cancelTransferApproval(ADDRESS1, ADDRESS2, amount);

        resUint256 = ruleConditionalTransferLight.approvedCount(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint256, 1);

        vm.prank(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);
        ruleConditionalTransferLight.cancelTransferApproval(ADDRESS1, ADDRESS2, amount);
        resUint256 = ruleConditionalTransferLight.approvedCount(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint256, 0);

        vm.expectRevert(TransferApprovalNotFound.selector);
        vm.prank(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);
        ruleConditionalTransferLight.cancelTransferApproval(ADDRESS1, ADDRESS2, amount);
    }

    function testFuzz_ApproveAndConsume(address from, address to, uint96 value, uint8 approvals, uint8 consumes)
        public
    {
        approvals = uint8(bound(approvals, 0, 20));
        consumes = uint8(bound(consumes, 0, approvals));
        bool isMintOrBurnPath = from == address(0) || to == address(0);

        for (uint256 i = 0; i < approvals; ++i) {
            vm.prank(CONDITIONAL_TRANSFER_OPERATOR_ADDRESS);
            ruleConditionalTransferLight.approveTransfer(from, to, value);
        }

        for (uint256 i = 0; i < consumes; ++i) {
            vm.prank(address(ruleEngineMock));
            ruleConditionalTransferLight.transferred(from, to, value);
        }

        resUint256 = ruleConditionalTransferLight.approvedCount(from, to, value);
        uint256 expectedCount = isMintOrBurnPath ? approvals : approvals - consumes;
        assertEq(resUint256, expectedCount);
    }
}
