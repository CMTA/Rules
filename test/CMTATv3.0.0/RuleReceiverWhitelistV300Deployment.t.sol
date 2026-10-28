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
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {
    RuleReceiverWhitelistInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleReceiverWhitelistInvariantStorage.sol";

/**
 * @title RuleReceiverWhitelist set at CMTAT v3.0.0 deployment
 * @notice The rule (or a RuleEngine holding it) passed in the token constructor: the first mint is screened
 * on the receiver, and a de-listed holder can still send to a listed receiver.
 */
contract RuleReceiverWhitelistV300DeploymentTest is Test, HelperContract {
    uint8 private constant CODE_RECEIVER = 90;
    RuleReceiverWhitelist private rule;

    function setUp() public {
        rule = new RuleReceiverWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
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

    /// @notice Rule set directly in the constructor: mint screened on the receiver (3-argument path on v3.0.0),
    /// transfers screened on the receiver only, burns exempt.
    function testRuleInConstructorScreensReceiverOnly() public {
        CMTATStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 10), CODE_RECEIVER);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        vm.expectPartialRevert(RuleReceiverWhitelistInvariantStorage.RuleReceiverWhitelist_InvalidTransfer.selector);
        token.mint(ADDRESS2, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();

        vm.prank(ADDRESS1);
        vm.expectPartialRevert(RuleReceiverWhitelistInvariantStorage.RuleReceiverWhitelist_InvalidTransfer.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 1);

        // De-list the holder and list the receiver: the holder can still exit.
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.removeAddress(ADDRESS1);
        rule.addAddress(ADDRESS2);
        vm.stopPrank();
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 4);
        assertEq(token.balanceOf(ADDRESS2), 4);

        // Burn from a de-listed holder passes.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burn(ADDRESS1, 6);
        assertEq(token.totalSupply(), 4);
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
        vm.expectPartialRevert(RuleReceiverWhitelistInvariantStorage.RuleReceiverWhitelist_InvalidTransfer.selector);
        token.mint(ADDRESS2, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();
        assertEq(token.balanceOf(ADDRESS1), 10);
    }
}
