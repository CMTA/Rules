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
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {
    RuleSpenderWhitelistInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleSpenderWhitelistInvariantStorage.sol";

/**
 * @title RuleSpenderWhitelist set at CMTAT v3.0.0 deployment
 * @notice The rule (or a RuleEngine holding it) passed in the token constructor: only `transferFrom` is
 * screened, on the spender; direct transfers, mints and burns pass.
 */
contract RuleSpenderWhitelistV300DeploymentTest is Test, HelperContract {
    uint8 private constant CODE_SPENDER = 66;
    RuleSpenderWhitelist private rule;

    function setUp() public {
        rule = new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS2);
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

    function _checkSpenderScreening(CMTATStandalone token) private {
        // Mint, direct transfer and burn are not screened.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.mint(ADDRESS1, 100);
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS3, 10);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burn(ADDRESS3, 10);

        // Unlisted spender rejected, listed spender accepted.
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
    function testRuleInConstructorScreensSpenderOnly() public {
        CMTATStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));
        _checkSpenderScreening(token);
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
        vm.stopPrank();
        _checkSpenderScreening(token);
    }
}
