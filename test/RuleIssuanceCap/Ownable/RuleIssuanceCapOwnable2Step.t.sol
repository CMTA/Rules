// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../../HelperContract.sol";
import {Ownable2StepTestBase, IOwnable2StepLike} from "../../utils/Ownable2StepTestBase.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {RuleIssuanceCapOwnable2Step} from "src/rules/operation/RuleIssuanceCapOwnable2Step.sol";
import {RuleIssuanceCapInvariantStorage} from "src/rules/operation/abstract/RuleIssuanceCapInvariantStorage.sol";

contract RuleIssuanceCapOwnable2StepTest is Ownable2StepTestBase {
    function _deployOwnable2Step() internal override returns (IOwnable2StepLike, address) {
        address ownerAddr = WHITELIST_OPERATOR_ADDRESS;
        RuleIssuanceCapOwnable2Step rule =
            new RuleIssuanceCapOwnable2Step(ownerAddr, address(new TotalSupplyMock()), 100, 0);
        return (IOwnable2StepLike(address(rule)), ownerAddr);
    }
}

contract RuleIssuanceCapOwnable2StepAccessControl is Test, HelperContract, RuleIssuanceCapInvariantStorage {
    error OwnableUnauthorizedAccount(address account);

    address private constant OWNER = WHITELIST_OPERATOR_ADDRESS;
    RuleIssuanceCapOwnable2Step private rule;

    function setUp() public {
        rule = new RuleIssuanceCapOwnable2Step(OWNER, address(new TotalSupplyMock()), 100, 0);
    }

    function testOwnerBindsAndManagesTheCap() public {
        vm.startPrank(OWNER);
        rule.bindToken(ADDRESS1);
        rule.setMaxTotalSupply(150);
        rule.increaseMaxTotalSupply(50);
        rule.decreaseMaxTotalSupply(20);
        vm.stopPrank();
        assertEq(rule.maxTotalSupply(), 180);

        vm.prank(ADDRESS1);
        rule.transferred(ZERO_ADDRESS, ADDRESS2, 30);
        assertEq(rule.totalIssued(), 30);
    }

    function testNonOwnerCannotBindOrManageTheCap() public {
        bytes memory err = abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER);
        vm.expectRevert(err);
        vm.prank(ATTACKER);
        rule.bindToken(ATTACKER);
        vm.expectRevert(err);
        vm.prank(ATTACKER);
        rule.setMaxTotalSupply(1);
        vm.expectRevert(err);
        vm.prank(ATTACKER);
        rule.increaseMaxTotalSupply(1);
    }

    function testTokenContractIsLockedEvenForTheOwner() public {
        address other = address(new TotalSupplyMock());
        vm.expectRevert(RuleIssuanceCap_TokenContractLocked.selector);
        vm.prank(OWNER);
        rule.setTokenContract(other);
    }
}
