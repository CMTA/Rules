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
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {
    RuleERC2980InvariantStorage
} from "src/rules/validation/abstract/RuleERC2980/invariantStorage/RuleERC2980InvariantStorage.sol";

/**
 * @title RuleERC2980 on a CMTAT v3.3 token
 * @notice The rule (or a RuleEngine holding it) passed in the token constructor. On v3.3 the minter and
 * the burner reach the rule as `spender`, so the frozenlist screens them.
 */
contract RuleERC2980CMTATDeploymentTest is Test, HelperContract {
    RuleERC2980 private rule;
    address private constant MINTER = address(0x4D1);

    function setUp() public {
        rule = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addWhitelistAddress(ADDRESS1);
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

    /// @notice Rule set directly in the constructor: the first mint is screened on the receiver, a minter
    /// that is not whitelisted can issue, a frozen minter cannot, and a de-listed sender can still send.
    function testRuleInConstructorScreensFirstMintAndFrozenMinter() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.grantRole(keccak256("MINTER_ROLE"), MINTER);

        vm.startPrank(MINTER);
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransferFrom.selector);
        token.mint(ADDRESS2, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();
        assertEq(token.balanceOf(ADDRESS1), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addFrozenlistAddress(MINTER);
        assertEq(
            token.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 1),
            rule.CODE_ADDRESS_SPENDER_IS_FROZEN()
        );
        vm.prank(MINTER);
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransferFrom.selector);
        token.mint(ADDRESS1, 10);

        // The receiver is whitelisted, the sender is removed: ERC-2980 lets it send what it holds.
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.addWhitelistAddress(ADDRESS2);
        rule.removeWhitelistAddress(ADDRESS1);
        vm.stopPrank();
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
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransferFrom.selector);
        token.mint(ADDRESS2, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();
        assertEq(token.balanceOf(ADDRESS1), 10);
    }
}
