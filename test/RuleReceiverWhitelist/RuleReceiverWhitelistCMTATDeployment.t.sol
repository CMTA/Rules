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
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {
    RuleReceiverWhitelistInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleReceiverWhitelistInvariantStorage.sol";

/**
 * @title RuleReceiverWhitelist on CMTAT v3.3
 * @notice The deployment orders the guide documents, on a real token: the rule or a RuleEngine passed in the
 * token constructor, and the rule set with `setRuleEngine` afterwards. Mints reach the rule on the 4-argument
 * path with the minter as spender, which the rule never screens.
 */
contract RuleReceiverWhitelistCMTATDeploymentTest is Test, HelperContract {
    uint8 private constant CODE_RECEIVER = 81;
    address private constant MINTER = address(0x4D1);
    RuleReceiverWhitelist private rule;

    function setUp() public {
        rule = new RuleReceiverWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
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

    /// @dev Unlisted minter mints to a listed receiver; a de-listed holder exits through an unlisted spender.
    function _checkReceiverScreening(CMTATStandardStandalone token) private {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.grantRole(keccak256("MINTER_ROLE"), MINTER);
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 10), CODE_RECEIVER);

        vm.startPrank(MINTER);
        vm.expectPartialRevert(RuleReceiverWhitelistInvariantStorage.RuleReceiverWhitelist_InvalidTransferFrom.selector);
        token.mint(ADDRESS2, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();

        vm.prank(ADDRESS1);
        vm.expectPartialRevert(RuleReceiverWhitelistInvariantStorage.RuleReceiverWhitelist_InvalidTransfer.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 1);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.removeAddress(ADDRESS1);
        rule.addAddress(ADDRESS2);
        vm.stopPrank();
        vm.prank(ADDRESS1);
        token.approve(ADDRESS3, 4);
        vm.prank(ADDRESS3);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(ADDRESS1, ADDRESS2, 4);
        assertEq(token.balanceOf(ADDRESS2), 4);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burn(ADDRESS1, 6);
        assertEq(token.totalSupply(), 4);
    }

    /// @notice Rule set directly in the constructor.
    function testRuleInConstructor() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));
        _checkReceiverScreening(token);
    }

    /// @notice Rule set directly with `setRuleEngine` after deployment.
    function testRuleSetDirectlyAfterDeployment() public {
        CMTATStandardStandalone token = _deployToken(ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.setRuleEngine(IRuleEngine(address(rule)));
        _checkReceiverScreening(token);
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
        _checkReceiverScreening(token);
    }
}
