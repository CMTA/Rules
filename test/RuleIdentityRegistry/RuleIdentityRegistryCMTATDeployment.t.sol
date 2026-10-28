// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {ICMTATConstructor, CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {TokenBindingModuleInvariantStorage} from "RuleEngine/modules/library/TokenBindingModuleInvariantStorage.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";

/**
 * @title RuleIdentityRegistry set at CMTAT v3.3 deployment
 * @notice The rule (or a RuleEngine holding it) passed in the token constructor, consulting an
 * `IdentityRegistryWhitelist`. The minter reaches the rule as `spender` on v3.3 and stays exempt, even
 * with `checkSpender` on.
 */
contract RuleIdentityRegistryCMTATDeploymentTest is Test, HelperContract {
    IdentityRegistryWhitelist private registry;
    RuleIdentityRegistry private rule;
    address private constant MINTER = address(0x4D1);

    function setUp() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        registry = new IdentityRegistryWhitelist(DEFAULT_ADMIN_ADDRESS);
        registry.registerIdentity(ADDRESS1, ZERO_ADDRESS, 0);
        vm.stopPrank();
        rule = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry), false, true);
    }

    function _deployToken(address ruleEngine_) private returns (CMTATStandardStandalone) {
        return new CMTATStandardStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(ruleEngine_))
        );
    }

    /// @notice Rule set directly in the constructor: an unregistered minter issues to a registered wallet
    /// only, an unregistered `transferFrom` spender is rejected, a de-listed holder can still send.
    function testRuleInConstructorScreensReceiverNotMinter() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.grantRole(keccak256("MINTER_ROLE"), MINTER);
        assertFalse(registry.isVerified(MINTER));

        vm.startPrank(MINTER);
        vm.expectPartialRevert(RuleIdentityRegistry_InvalidTransferFrom.selector);
        token.mint(ADDRESS2, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();
        assertEq(token.balanceOf(ADDRESS1), 10);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        registry.registerIdentity(ADDRESS2, ZERO_ADDRESS, 0);
        registry.deleteIdentity(ADDRESS1);
        vm.stopPrank();

        vm.prank(ADDRESS1);
        token.approve(ADDRESS3, 1);
        assertEq(
            token.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 1), CODE_ADDRESS_SPENDER_NOT_VERIFIED
        );
        vm.prank(ADDRESS3);
        vm.expectPartialRevert(RuleIdentityRegistry_InvalidTransferFrom.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(ADDRESS1, ADDRESS2, 1);

        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 1);
        assertEq(token.balanceOf(ADDRESS2), 1);
    }

    /// @notice RuleEngine in the constructor: nothing moves until the engine binds the token.
    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        engine.addRule(IRule(address(rule)));
        CMTATStandardStandalone token = _deployToken(address(engine));

        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 10);

        engine.bindToken(address(token));
        vm.expectPartialRevert(RuleIdentityRegistry_InvalidTransferFrom.selector);
        token.mint(ADDRESS2, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();
        assertEq(token.balanceOf(ADDRESS1), 10);
    }
}
