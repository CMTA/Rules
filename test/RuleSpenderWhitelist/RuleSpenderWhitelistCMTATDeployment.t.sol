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
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {
    RuleSpenderWhitelistInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleSpenderWhitelistInvariantStorage.sol";

/**
 * @title RuleSpenderWhitelist on CMTAT v3.3
 * @notice The deployment orders the guide documents, on a real token. On v3.3 the minter and the burner reach
 * the rule as `spender` on the 4-argument path; the rule exempts mint and burn, so an unlisted minter and
 * burner still operate. Only a `transferFrom` spender is screened.
 */
contract RuleSpenderWhitelistCMTATDeploymentTest is Test, HelperContract {
    uint8 private constant CODE_SPENDER = 66;
    address private constant MINTER = address(0x4D1);
    RuleSpenderWhitelist private rule;

    function setUp() public {
        rule = new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS2);
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

    function _checkSpenderScreening(CMTATStandardStandalone token) private {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        token.grantRole(keccak256("MINTER_ROLE"), MINTER);
        token.grantRole(keccak256("BURNER_ROLE"), MINTER);
        vm.stopPrank();

        // Unlisted minter and burner, unlisted direct-transfer receiver: all pass.
        vm.prank(MINTER);
        token.mint(ADDRESS1, 100);
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS3, 10);
        vm.prank(MINTER);
        token.burn(ADDRESS3, 10);

        vm.startPrank(ADDRESS1);
        token.approve(ADDRESS3, 10);
        token.approve(ADDRESS2, 10);
        vm.stopPrank();
        assertEq(token.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10), CODE_SPENDER);
        vm.prank(ADDRESS3);
        vm.expectPartialRevert(RuleSpenderWhitelistInvariantStorage.RuleSpenderWhitelist_InvalidTransferFrom.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(ADDRESS1, ADDRESS2, 10);
        vm.prank(ADDRESS2);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(ADDRESS1, ADDRESS3, 10);
        assertEq(token.balanceOf(ADDRESS3), 10);
    }

    /// @notice Rule set directly in the constructor.
    function testRuleInConstructor() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));
        _checkSpenderScreening(token);
    }

    /// @notice Rule set directly with `setRuleEngine` after deployment.
    function testRuleSetDirectlyAfterDeployment() public {
        CMTATStandardStandalone token = _deployToken(ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.setRuleEngine(IRuleEngine(address(rule)));
        _checkSpenderScreening(token);
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
        vm.stopPrank();
        _checkSpenderScreening(token);
    }
}
