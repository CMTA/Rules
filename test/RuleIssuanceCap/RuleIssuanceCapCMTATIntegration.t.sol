// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";

/**
 * @title RuleIssuanceCap on the current CMTAT (>= v3.3)
 * @notice Mints reach the rule on the 4-argument path with the minter as spender; the spender is ignored.
 */
contract RuleIssuanceCapCMTATIntegration is Test, HelperContract {
    uint256 private constant CAP = 100;
    RuleIssuanceCap private rule;

    function _setUpTopology(bool viaEngine) private {
        cmtatContract = new CMTATDeployment().cmtat();
        rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(cmtatContract), CAP, 0);
        address caller = address(cmtatContract);
        address target = address(rule);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        if (viaEngine) {
            ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(cmtatContract));
            ruleEngineMock.addRule(rule);
            caller = address(ruleEngineMock);
            target = address(ruleEngineMock);
        }
        rule.bindToken(caller);
        cmtatContract.setRuleEngine(IRuleEngine(target));
        cmtatContract.mint(ADDRESS1, 60);
        vm.stopPrank();
    }

    function _burnDoesNotRestoreTheCap() private {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.burn(ADDRESS1, 30);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransferFrom.selector);
        cmtatContract.mint(ADDRESS2, 41);
        cmtatContract.mint(ADDRESS2, 40);
        vm.stopPrank();
        assertEq(rule.totalIssued(), CAP);
        assertEq(cmtatContract.totalSupply(), 70);
    }

    function testBurnDoesNotRestoreTheCapDirect() public {
        _setUpTopology(false);
        _burnDoesNotRestoreTheCap();
    }

    function testBurnDoesNotRestoreTheCapViaRuleEngine() public {
        _setUpTopology(true);
        _burnDoesNotRestoreTheCap();
    }

    function testTokenViewReportsTheIssuanceCode() public {
        _setUpTopology(true);
        assertEq(cmtatContract.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 40), TRANSFER_OK);
        assertEq(cmtatContract.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 41), 71);
        // The burn frees live-supply room (supply 30) but not issuance room: still 71, not OK.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.burn(ADDRESS1, 30);
        assertEq(cmtatContract.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 41), 71);
    }
}
