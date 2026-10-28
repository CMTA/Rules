// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {ICMTATConstructor, CMTATStandalone} from "CMTATv3.0.0/deployment/CMTATStandalone.sol";
import {IRuleEngine} from "CMTATv3.0.0/interfaces/engine/IRuleEngine.sol";
import {ISnapshotEngine} from "CMTATv3.0.0/interfaces/engine/ISnapshotEngine.sol";
import {IERC1643} from "CMTATv3.0.0/interfaces/engine/IDocumentEngine.sol";
import {IERC1643CMTAT} from "CMTATv3.0.0/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {TokenBindingModuleInvariantStorage} from "RuleEngine/modules/library/TokenBindingModuleInvariantStorage.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {
    RuleERC2980InvariantStorage
} from "src/rules/validation/abstract/RuleERC2980/invariantStorage/RuleERC2980InvariantStorage.sol";

/**
 * @title RuleERC2980 set at CMTAT v3.0.0 deployment
 * @notice The rule (or a RuleEngine holding it) passed in the token constructor, rather than through
 * `setRuleEngine` afterwards: the token screens its very first mint.
 */
contract RuleERC2980V300DeploymentTest is Test, HelperContract {
    RuleERC2980 private rule;

    function setUp() public {
        rule = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addWhitelistAddress(ADDRESS1);
    }

    function _deployToken(address ruleEngine_) private returns (CMTATStandalone) {
        return new CMTATStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(ruleEngine_), ISnapshotEngine(ZERO_ADDRESS), IERC1643(ZERO_ADDRESS))
        );
    }

    /// @notice Rule set directly in the constructor: the first mint is screened on the receiver, the sender
    /// needs no whitelisting, and a frozen sender is blocked.
    function testRuleInConstructorScreensFirstMint() public {
        CMTATStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector);
        token.mint(ADDRESS2, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();

        assertEq(token.detectTransferRestriction(ADDRESS1, ADDRESS2, 1), rule.CODE_ADDRESS_TO_NOT_WHITELISTED());
        vm.prank(ADDRESS1);
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 1);

        // The receiver is whitelisted, the sender is removed: ERC-2980 lets it send what it holds.
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.addWhitelistAddress(ADDRESS2);
        rule.removeWhitelistAddress(ADDRESS1);
        vm.stopPrank();
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 1);
        assertEq(token.balanceOf(ADDRESS2), 1);

        // A frozen sender is blocked, whatever its whitelist status.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addFrozenlistAddress(ADDRESS1);
        assertEq(token.detectTransferRestriction(ADDRESS1, ADDRESS2, 1), rule.CODE_ADDRESS_FROM_IS_FROZEN());
        vm.prank(ADDRESS1);
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 1);
    }

    /// @notice RuleEngine in the constructor: nothing moves until the engine binds the token.
    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        engine.addRule(IRule(address(rule)));
        CMTATStandalone token = _deployToken(address(engine));

        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 10);

        engine.bindToken(address(token));
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector);
        token.mint(ADDRESS2, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();
        assertEq(token.balanceOf(ADDRESS1), 10);
    }
}
