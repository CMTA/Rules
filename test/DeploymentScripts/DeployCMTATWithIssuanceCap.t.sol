// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {RuleIssuanceCapInvariantStorage} from "src/rules/operation/abstract/RuleIssuanceCapInvariantStorage.sol";
import {DeployCMTATWithIssuanceCap} from "script/DeployCMTATWithIssuanceCap.s.sol";

contract DeployCMTATWithIssuanceCapTest is Test {
    address constant ADMIN = address(0xA11CE);
    address constant INVESTOR = address(0xB0B);
    address constant OTHER = address(0xCAFE);
    uint256 constant CAP = 1_000;

    DeployCMTATWithIssuanceCap script;
    CMTATStandardStandalone token;
    RuleIssuanceCap rule;

    function setUp() public {
        script = new DeployCMTATWithIssuanceCap();
        (token, rule) = script.deploy(ADMIN, address(script), address(0), CAP);
    }

    function testRuleIsSetOnTheTokenBoundAndObservesIt() public view {
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(rule.getTokenBound(), address(token));
        assertEq(address(rule.tokenContract()), address(token));
        assertEq(rule.maxTotalSupply(), CAP);
        assertEq(rule.totalIssued(), 0);
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
        (CMTATStandardStandalone t2, RuleIssuanceCap r2) =
            script.deploy(address(script), address(script), address(0), CAP);
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
        assertTrue(r2.hasRole(r2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testBurnsDoNotRestoreIssuanceRoom() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, CAP);
        assertEq(rule.totalIssued(), CAP);

        vm.prank(ADMIN);
        token.burn(INVESTOR, 100);
        assertEq(token.totalSupply(), CAP - 100);
        assertEq(rule.totalIssued(), CAP);

        assertEq(token.detectTransferRestriction(address(0), INVESTOR, 1), rule.CODE_ISSUANCE_CAP_EXCEEDED());
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(INVESTOR, 1);
    }

    function testTransfersAreNotCapped() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, CAP);
        vm.prank(INVESTOR);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 400);
        assertEq(token.balanceOf(OTHER), 400);
    }

    function testObservedTokenIsLocked() public {
        vm.prank(ADMIN);
        vm.expectRevert(RuleIssuanceCapInvariantStorage.RuleIssuanceCap_TokenContractLocked.selector);
        rule.setTokenContract(OTHER);
    }
}
