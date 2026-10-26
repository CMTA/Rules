// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../../HelperContract.sol";
import {Ownable2StepTestBase, IOwnable2StepLike} from "../../utils/Ownable2StepTestBase.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {RuleMaxTotalSupplyOwnable2Step} from "src/rules/validation/deployment/RuleMaxTotalSupplyOwnable2Step.sol";

contract RuleMaxTotalSupplyOwnable2StepTest is Ownable2StepTestBase {
    function _deployOwnable2Step() internal override returns (IOwnable2StepLike, address) {
        address ownerAddr = WHITELIST_OPERATOR_ADDRESS;
        TotalSupplyMock token = new TotalSupplyMock();
        RuleMaxTotalSupplyOwnable2Step rule = new RuleMaxTotalSupplyOwnable2Step(ownerAddr, address(token), 100);
        return (IOwnable2StepLike(address(rule)), ownerAddr);
    }
}

contract RuleMaxTotalSupplyOwnable2StepAccessControl is Test, HelperContract {
    error OwnableUnauthorizedAccount(address account);

    RuleMaxTotalSupplyOwnable2Step private rule;
    TotalSupplyMock private token;

    function setUp() public {
        token = new TotalSupplyMock();
        rule = new RuleMaxTotalSupplyOwnable2Step(WHITELIST_OPERATOR_ADDRESS, address(token), 100);
    }

    function testOwnerCanManageMaxTotalSupply() public {
        TotalSupplyMock newToken = new TotalSupplyMock();

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        rule.setMaxTotalSupply(150);
        assertEq(rule.maxTotalSupply(), 150);

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        rule.setTokenContract(address(newToken));
        assertEq(address(rule.tokenContract()), address(newToken));
    }

    function testOwnerCanIncreaseAndDecrease() public {
        vm.startPrank(WHITELIST_OPERATOR_ADDRESS);
        rule.increaseMaxTotalSupply(50);
        rule.decreaseMaxTotalSupply(30);
        vm.stopPrank();
        assertEq(rule.maxTotalSupply(), 120);
    }

    function testNonOwnerCannotIncreaseOrDecrease() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.increaseMaxTotalSupply(1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.decreaseMaxTotalSupply(1);
    }

    function testNonOwnerCannotManageMaxTotalSupply() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.setMaxTotalSupply(200);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.setTokenContract(address(token));
    }
}
