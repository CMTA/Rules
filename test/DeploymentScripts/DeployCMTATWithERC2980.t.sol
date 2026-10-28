// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {DeployCMTATWithERC2980} from "script/DeployCMTATWithERC2980.s.sol";

contract DeployCMTATWithERC2980Test is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);
    address constant OTHER = address(3);

    /// RuleERC2980InvariantStorage codes
    uint8 constant CODE_ADDRESS_FROM_IS_FROZEN = 60;
    uint8 constant CODE_ADDRESS_TO_NOT_WHITELISTED = 63;
    uint8 constant CODE_MINT_NOT_ALLOWED = 64;

    DeployCMTATWithERC2980 script;
    CMTATStandardStandalone token;
    RuleERC2980 rule;

    function setUp() public {
        script = new DeployCMTATWithERC2980();
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast.
        (token, rule) = script.deploy(ADMIN, address(script), address(0), true);
    }

    function testSetsTheRuleOnTheToken() public view {
        assertEq(address(token.ruleEngine()), address(rule));
    }

    function testHandsAdminRoleToAdmin() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function testDeployerRetainsNoAdminRole() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testAdminEqualToDeployerKeepsTheRole() public {
        (CMTATStandardStandalone t2,) = script.deploy(address(script), address(script), address(0), true);
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testMintToWhitelistedInvestorSucceeds() public {
        vm.prank(ADMIN);
        rule.addWhitelistAddress(INVESTOR);
        assertEq(token.detectTransferRestrictionFrom(ADMIN, address(0), INVESTOR, 100), 0);

        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 100);
    }

    function testMintToNonWhitelistedAddressIsRejected() public {
        assertEq(token.detectTransferRestrictionFrom(ADMIN, address(0), OTHER, 1), CODE_ADDRESS_TO_NOT_WHITELISTED);
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(OTHER, 1);
    }

    function testFrozenHolderCannotSend() public {
        vm.startPrank(ADMIN);
        rule.addWhitelistAddress(INVESTOR);
        rule.addWhitelistAddress(OTHER);
        token.mint(INVESTOR, 100);
        rule.addFrozenlistAddress(INVESTOR);
        vm.stopPrank();

        assertEq(token.detectTransferRestriction(INVESTOR, OTHER, 1), CODE_ADDRESS_FROM_IS_FROZEN);
        vm.prank(INVESTOR);
        vm.expectRevert();
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 1);
    }

    function testMintIsRejectedWhenMintBurnIsNotAllowed() public {
        (CMTATStandardStandalone t2, RuleERC2980 r2) = script.deploy(ADMIN, address(script), address(0), false);
        vm.prank(ADMIN);
        r2.addWhitelistAddress(INVESTOR);

        assertEq(t2.detectTransferRestrictionFrom(ADMIN, address(0), INVESTOR, 1), CODE_MINT_NOT_ALLOWED);
        vm.prank(ADMIN);
        vm.expectRevert();
        t2.mint(INVESTOR, 1);
    }
}
