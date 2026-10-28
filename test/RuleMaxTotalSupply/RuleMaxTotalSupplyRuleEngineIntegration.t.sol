// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";

/**
 * @title Integration test between RuleEngine and RuleMaxTotalSupply
 */
contract RuleMaxTotalSupplyRuleEngineIntegration is Test, HelperContract {
    TotalSupplyMock token;

    function setUp() public {
        token = new TotalSupplyMock();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleMaxTotalSupply = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), 100);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleMaxTotalSupply);
    }

    function testDetectRestrictionForMintExceedingMaxSupply() public {
        token.setTotalSupply(90);
        resUint8 = ruleEngineMock.detectTransferRestriction(address(0), ADDRESS1, 15);
        assertEq(resUint8, CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
        resBool = ruleEngineMock.canTransfer(address(0), ADDRESS1, 15);
        assertEq(resBool, false);
    }

    function testDetectRestrictionForMintWithinMaxSupply() public {
        token.setTotalSupply(90);
        resUint8 = ruleEngineMock.detectTransferRestriction(address(0), ADDRESS1, 10);
        assertEq(resUint8, TRANSFER_OK);
        resBool = ruleEngineMock.canTransfer(address(0), ADDRESS1, 10);
        assertEq(resBool, true);
    }

    function testTransfersNotAffectedByMaxSupplyRule() public {
        token.setTotalSupply(100);
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, 50);
        assertEq(resUint8, TRANSFER_OK);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, 50);
        assertEq(resBool, true);
    }

    function testSetMaxTotalSupplyToZero() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleMaxTotalSupply.setMaxTotalSupply(0);

        token.setTotalSupply(0);
        resUint8 = ruleEngineMock.detectTransferRestriction(address(0), ADDRESS1, 1);
        assertEq(resUint8, CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
        resBool = ruleEngineMock.canTransfer(address(0), ADDRESS1, 1);
        assertEq(resBool, false);
    }

    /// @notice Full-domain fuzz: `value`, `currentSupply` and `maxSupply` roam the entire uint256
    ///         range, including the region where `currentSupply + value` overflows. The view must
    ///         return a code and never revert (regression guard for the overflow fix).
    function testFuzz_MaxTotalSupplyBounds(uint256 currentSupply, uint256 value, uint256 maxSupply) public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleMaxTotalSupply.setMaxTotalSupply(maxSupply);

        token.setTotalSupply(currentSupply);
        resUint8 = ruleEngineMock.detectTransferRestriction(address(0), ADDRESS1, value);

        // Overflow-safe reference computation, mirroring the rule's own logic.
        bool exceeds = currentSupply > maxSupply || value > maxSupply - currentSupply;
        if (exceeds) {
            assertEq(resUint8, CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
        } else {
            assertEq(resUint8, TRANSFER_OK);
        }
    }
}
