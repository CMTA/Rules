// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {DeployCMTATWithWhitelistWrapper} from "script/DeployCMTATWithWhitelistWrapper.s.sol";

contract DeployCMTATWithWhitelistWrapperTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR_A = address(2);
    address constant INVESTOR_B = address(3);
    address constant STRANGER = address(0x57A2);

    /// RuleWhitelistInvariantStorage.CODE_ADDRESS_TO_NOT_WHITELISTED / CODE_MINT_NOT_ALLOWED
    uint8 constant CODE_ADDRESS_TO_NOT_WHITELISTED = 22;
    uint8 constant CODE_MINT_NOT_ALLOWED = 24;

    DeployCMTATWithWhitelistWrapper script;
    CMTATStandardStandalone token;
    RuleWhitelistWrapper wrapper;
    RuleWhitelist childA;
    RuleWhitelist childB;

    function setUp() public {
        script = new DeployCMTATWithWhitelistWrapper();
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast.
        (token, wrapper, childA, childB) = script.deploy(ADMIN, address(script), address(0), false, true);
    }

    function testSetsOnlyTheWrapperOnTheToken() public view {
        assertEq(address(token.ruleEngine()), address(wrapper));
        assertEq(wrapper.rulesCount(), 2);
        assertTrue(wrapper.containsRule(IRule(address(childA))));
        assertTrue(wrapper.containsRule(IRule(address(childB))));
        assertTrue(address(childA) != address(childB));
    }

    function testHandsAdminRoleToAdmin() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(wrapper.hasRole(wrapper.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(childA.hasRole(childA.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(childB.hasRole(childB.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function testDeployerRetainsNoRole() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(wrapper.hasRole(wrapper.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(wrapper.hasRole(wrapper.RULES_MANAGEMENT_ROLE(), address(script)));
        assertFalse(childA.hasRole(childA.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(childB.hasRole(childB.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testAdminEqualToDeployerKeepsTheRole() public {
        (CMTATStandardStandalone t2, RuleWhitelistWrapper w2,,) =
            script.deploy(address(script), address(script), address(0), false, true);
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
        assertTrue(w2.hasRole(w2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    /// The point of the wrapper: an address listed by either child is accepted, across children.
    function testTransferBetweenInvestorsListedInDifferentChildrenSucceeds() public {
        vm.startPrank(ADMIN);
        childA.addAddress(INVESTOR_A);
        childB.addAddress(INVESTOR_B);
        token.mint(INVESTOR_A, 100);
        vm.stopPrank();

        assertEq(token.detectTransferRestriction(INVESTOR_A, INVESTOR_B, 10), 0);
        vm.prank(INVESTOR_A);
        token.transfer(INVESTOR_B, 10);
        assertEq(token.balanceOf(INVESTOR_B), 10);
    }

    function testTransferToAnAddressListedInNoChildIsRejected() public {
        vm.startPrank(ADMIN);
        childA.addAddress(INVESTOR_A);
        token.mint(INVESTOR_A, 100);
        vm.stopPrank();

        assertEq(token.detectTransferRestriction(INVESTOR_A, STRANGER, 10), CODE_ADDRESS_TO_NOT_WHITELISTED);
        vm.prank(INVESTOR_A);
        vm.expectRevert();
        token.transfer(STRANGER, 10);
    }

    /// With `allowMintBurn = false` the token cannot be issued at all.
    function testMintIsRejectedWhenMintBurnIsNotAllowed() public {
        (CMTATStandardStandalone t2,, RuleWhitelist a2,) =
            script.deploy(ADMIN, address(script), address(0), false, false);
        vm.prank(ADMIN);
        a2.addAddress(INVESTOR_A);

        assertEq(t2.detectTransferRestriction(address(0), INVESTOR_A, 100), CODE_MINT_NOT_ALLOWED);
        vm.prank(ADMIN);
        vm.expectRevert();
        t2.mint(INVESTOR_A, 100);
    }
}
