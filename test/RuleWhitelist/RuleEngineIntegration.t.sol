// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";

/**
 * @title Integration test between RuleEngine and RuleWhitelist
 */
contract RuleEngineIntegration is Test, HelperContract {
    // Custom error OpenZeppelin
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, false);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
    }

    function testRulesManagerRoleRequiredToAddRule() public {
        bytes32 rulesManagerRole = ruleEngineMock.RULES_MANAGEMENT_ROLE();

        // Non-authorized account cannot add a rule.
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ATTACKER, rulesManagerRole));
        vm.prank(ATTACKER);
        ruleEngineMock.addRule(ruleWhitelist);

        // Grant RULES_MANAGEMENT_ROLE to operator and add the rule.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.grantRole(rulesManagerRole, RULE_ENGINE_OPERATOR_ADDRESS);

        vm.prank(RULE_ENGINE_OPERATOR_ADDRESS);
        ruleEngineMock.addRule(ruleWhitelist);

        assertEq(ruleEngineMock.rulesCount(), 1);
        assertTrue(ruleEngineMock.containsRule(ruleWhitelist));
    }

    function testDetectRestrictionAndCanTransfer() public {
        uint256 amount = 10;
        bytes32 rulesManagerRole = ruleEngineMock.RULES_MANAGEMENT_ROLE();

        // Grant rule management and add rule.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.grantRole(rulesManagerRole, DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleWhitelist);

        // No whitelist entries: should block and return FROM not whitelisted.
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_FROM_NOT_WHITELISTED);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);

        // Add sender only: should block on TO not whitelisted.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);

        // Add recipient: should allow transfer.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, true);
    }
}
