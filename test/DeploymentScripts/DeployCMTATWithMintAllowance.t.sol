// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";
import {DeployCMTATWithMintAllowance} from "script/DeployCMTATWithMintAllowance.s.sol";

contract DeployCMTATWithMintAllowanceTest is Test {
    address constant ADMIN = address(0xA11CE);
    address constant INVESTOR = address(0xB0B);
    address constant OTHER = address(0xCAFE);

    DeployCMTATWithMintAllowance script;
    CMTATStandardStandalone token;
    RuleMintAllowance rule;

    function setUp() public {
        script = new DeployCMTATWithMintAllowance();
        (token, rule) = script.deploy(ADMIN, address(script), address(0));
    }

    function testRuleIsSetOnTheTokenAndBoundToIt() public view {
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(rule.getTokenBound(), address(token));
    }

    function testHandsAdminRoleToAdminOnTokenAndRule() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function testDeployerRetainsNoAdminRole() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testAdminEqualToDeployerKeepsTheRole() public {
        (CMTATStandardStandalone t2, RuleMintAllowance r2) = script.deploy(address(script), address(script), address(0));
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
        assertTrue(r2.hasRole(r2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testNoQuotaIsSetSoEvenTheAdminCannotMint() public {
        assertEq(rule.mintAllowance(ADMIN), 0);
        assertEq(
            token.detectTransferRestrictionFrom(ADMIN, address(0), INVESTOR, 1), rule.CODE_MINTER_ALLOWANCE_EXCEEDED()
        );

        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(INVESTOR, 1);
    }

    function testMintPassesAndIsDebitedOnceAQuotaIsSet() public {
        vm.prank(ADMIN);
        rule.setMintAllowance(ADMIN, 100);
        assertEq(token.detectTransferRestrictionFrom(ADMIN, address(0), INVESTOR, 100), 0);

        vm.prank(ADMIN);
        token.mint(INVESTOR, 60);
        assertEq(token.balanceOf(INVESTOR), 60);
        assertEq(rule.mintAllowance(ADMIN), 40);

        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(INVESTOR, 41);
    }

    function testTransfersAreNotRestricted() public {
        vm.prank(ADMIN);
        rule.setMintAllowance(ADMIN, 100);
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);

        vm.prank(INVESTOR);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 30);
        assertEq(token.balanceOf(OTHER), 30);
    }
}
