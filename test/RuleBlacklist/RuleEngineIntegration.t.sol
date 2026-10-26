// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";

/**
 * @title Integration test between RuleEngine and RuleBlacklist
 */
contract RuleBlacklistRuleEngineIntegration is Test, HelperContract {
    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleBlacklist);
    }

    function testDetectRestrictionAndCanTransfer() public {
        uint256 amount = 10;

        // No blacklisted entries: should allow.
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, true);

        // Blacklist sender: should block.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS1);
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_FROM_IS_BLACKLISTED);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);

        // Blacklist spender: should block via detectTransferRestrictionFrom.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS3);
        resUint8 = ruleEngineMock.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_SPENDER_IS_BLACKLISTED);
        resBool = ruleEngineMock.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);
    }
}
