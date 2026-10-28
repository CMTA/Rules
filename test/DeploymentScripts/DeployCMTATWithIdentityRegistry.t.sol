// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {DeployCMTATWithIdentityRegistry} from "script/DeployCMTATWithIdentityRegistry.s.sol";

contract DeployCMTATWithIdentityRegistryTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);
    address constant OTHER = address(3);

    /// RuleIdentityRegistryInvariantStorage.CODE_ADDRESS_TO_NOT_VERIFIED
    uint8 constant CODE_ADDRESS_TO_NOT_VERIFIED = 56;

    DeployCMTATWithIdentityRegistry script;
    CMTATStandardStandalone token;
    IdentityRegistryWhitelist registry;
    RuleIdentityRegistry rule;

    function setUp() public {
        script = new DeployCMTATWithIdentityRegistry();
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast.
        (token, registry, rule) = script.deploy(ADMIN, address(script), address(0), false, false);
    }

    function _register(address wallet) internal {
        vm.prank(ADMIN);
        registry.registerIdentity(wallet, address(0), 0);
    }

    function testSetsTheRuleOnTheTokenAndPointsItAtTheRegistry() public view {
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(address(rule.identityRegistry()), address(registry));
        assertFalse(rule.checkSender());
        assertFalse(rule.checkSpender());
    }

    function testHandsAdminRoleToAdmin() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function testDeployerRetainsNoAdminRole() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testAdminEqualToDeployerKeepsTheRole() public {
        (CMTATStandardStandalone t2,,) = script.deploy(address(script), address(script), address(0), false, false);
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testMintToRegisteredReceiverSucceeds() public {
        _register(INVESTOR);
        assertEq(token.detectTransferRestrictionFrom(ADMIN, address(0), INVESTOR, 100), 0);

        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 100);
    }

    function testMintToUnregisteredReceiverIsRejected() public {
        assertEq(token.detectTransferRestrictionFrom(ADMIN, address(0), OTHER, 1), CODE_ADDRESS_TO_NOT_VERIFIED);
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(OTHER, 1);
    }

    /// Receiver-only screening: a holder removed from the registry can still exit their position.
    function testDelistedHolderCanStillSend() public {
        _register(INVESTOR);
        _register(OTHER);
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        vm.prank(ADMIN);
        registry.deleteIdentity(INVESTOR);

        assertEq(token.detectTransferRestriction(INVESTOR, OTHER, 40), 0);
        vm.prank(INVESTOR);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OTHER, 40);
        assertEq(token.balanceOf(OTHER), 40);

        // ...but can no longer receive.
        assertEq(token.detectTransferRestriction(OTHER, INVESTOR, 1), CODE_ADDRESS_TO_NOT_VERIFIED);
        vm.prank(OTHER);
        vm.expectRevert();
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(INVESTOR, 1);
    }
}
