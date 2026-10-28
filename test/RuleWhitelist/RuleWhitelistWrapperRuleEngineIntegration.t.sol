// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";

/**
 * @title Integration test between RuleEngine and RuleWhitelistWrapper
 */
contract RuleWhitelistWrapperRuleEngineIntegration is Test, HelperContract {
    RuleWhitelistWrapper ruleWhitelistWrapper;

    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, false);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelistWrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, true);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelistWrapper.addRule(ruleWhitelist);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleWhitelistWrapper);
    }

    function testDetectRestrictionAndCanTransfer() public {
        uint256 amount = 10;

        // No whitelist entries: should block.
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_FROM_NOT_WHITELISTED);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);

        // Add sender only: should block on recipient.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);

        // Add recipient: should allow.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, true);
    }

    function testDetectRestrictionFromAndCanTransferFrom() public {
        uint256 amount = 10;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);

        // Spender not whitelisted.
        resUint8 = ruleEngineMock.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);
        resBool = ruleEngineMock.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);

        // Whitelist spender: should allow.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS3);
        resUint8 = ruleEngineMock.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        resBool = ruleEngineMock.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, true);
    }
}
