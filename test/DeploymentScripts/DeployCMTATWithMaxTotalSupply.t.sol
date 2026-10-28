// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {DeployCMTATWithMaxTotalSupply} from "script/DeployCMTATWithMaxTotalSupply.s.sol";

contract DeployCMTATWithMaxTotalSupplyTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);
    address constant OTHER = address(3);
    uint256 constant CAP = 1_000;

    /// RuleMaxTotalSupplyInvariantStorage.CODE_MAX_TOTAL_SUPPLY_EXCEEDED
    uint8 constant CODE_MAX_TOTAL_SUPPLY_EXCEEDED = 50;

    DeployCMTATWithMaxTotalSupply script;
    CMTATStandardStandalone token;
    RuleMaxTotalSupply rule;

    function setUp() public {
        script = new DeployCMTATWithMaxTotalSupply();
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast, so
        // it makes the wiring calls itself.
        (token, rule) = script.deploy(ADMIN, address(script), address(0), CAP);
    }

    function testBindsTheRuleToTheToken() public view {
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(address(rule.tokenContract()), address(token));
        assertEq(rule.maxTotalSupply(), CAP);
    }

    function testHandsAdminRoleToAdmin() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function testDeployerRetainsNoAdminRole() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testRuleAdminIsAdmin() public view {
        assertTrue(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertFalse(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testCanMintUpToTheCap() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, CAP);
        assertEq(token.totalSupply(), CAP);
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, 0);
        assertEq(headroom, 0);
    }

    function testMintAboveTheCapIsRejected() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, CAP);
        assertEq(token.detectTransferRestriction(address(0), INVESTOR, 1), CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(INVESTOR, 1);
    }

    function testTransfersAreNotCappedAndBurnFreesRoom() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, CAP);
        vm.prank(INVESTOR);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 400);
        vm.prank(ADMIN);
        token.burn(OTHER, 100);
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        assertEq(token.totalSupply(), CAP);
    }

    function testAdminCanRaiseTheCap() public {
        vm.prank(ADMIN);
        rule.increaseMaxTotalSupply(500);
        assertEq(rule.maxTotalSupply(), CAP + 500);
    }
}
