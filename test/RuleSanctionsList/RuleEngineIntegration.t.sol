// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";

/**
 * @title Integration test between RuleEngine and RuleSanctionsList
 */
contract RuleSanctionsListRuleEngineIntegration is Test, HelperContract {
    RuleSanctionsList ruleSanctionList;
    SanctionListOracle sanctionListOracle;

    function setUp() public {
        sanctionListOracle = new SanctionListOracle();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleSanctionList = new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, sanctionListOracle);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleSanctionList);
    }

    function testDetectRestrictionAndCanTransfer() public {
        uint256 amount = 10;

        // No sanctioned entries: should allow.
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, true);

        // Sanction sender: should block.
        sanctionListOracle.addToSanctionsList(ADDRESS1);
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_FROM_IS_SANCTIONED);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);

        // Sanction spender: should block via detectTransferRestrictionFrom.
        sanctionListOracle.addToSanctionsList(ADDRESS3);
        resUint8 = ruleEngineMock.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_SPENDER_IS_SANCTIONED);
        resBool = ruleEngineMock.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);
    }
}
