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
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";

/**
 * @title RuleSanctionsList set at CMTAT v3.0.0 deployment
 * @notice The rule (or a RuleEngine holding it) passed in the token constructor, with the oracle set in
 * the rule constructor. v3.0.0 forwards no minter, so a sanctioned minter is not stopped.
 */
contract RuleSanctionsListV300DeploymentTest is Test, HelperContract {
    SanctionListOracle private oracle;
    RuleSanctionsList private rule;

    function setUp() public {
        oracle = new SanctionListOracle();
        oracle.addToSanctionsList(ADDRESS3);
        rule = new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ISanctionsList(address(oracle)));
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

    /// @notice Rule set directly in the constructor: a mint to a sanctioned receiver is rejected on the
    /// 3-argument path, and a sanctioned holder can neither send nor be burned from.
    function testRuleInConstructorScreensFirstMint() public {
        CMTATStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS3, 1), CODE_ADDRESS_TO_IS_SANCTIONED);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransfer.selector);
        token.mint(ADDRESS3, 10);
        token.mint(ADDRESS1, 10);
        oracle.addToSanctionsList(ADDRESS1);
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransfer.selector);
        token.burn(ADDRESS1, 1);
        vm.stopPrank();

        vm.prank(ADDRESS1);
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransfer.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 1);
    }

    /// @notice v3.0.0 limitation: the minter never reaches the rule, so a sanctioned minter is not stopped.
    function testSanctionedMinterIsNotScreened() public {
        CMTATStandalone token = _deployToken(address(rule));
        oracle.addToSanctionsList(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.mint(ADDRESS1, 10);
        assertEq(token.balanceOf(ADDRESS1), 10);
    }

    /// @notice A rule deployed without an oracle fails open until `setSanctionListOracle` is called.
    function testRuleWithoutOracleFailsOpenUntilSet() public {
        RuleSanctionsList bare =
            new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ISanctionsList(ZERO_ADDRESS));
        CMTATStandalone token = _deployToken(address(bare));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.mint(ADDRESS3, 10);
        assertEq(token.balanceOf(ADDRESS3), 10);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        bare.setSanctionListOracle(ISanctionsList(address(oracle)));
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransfer.selector);
        token.mint(ADDRESS3, 10);
        vm.stopPrank();
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
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransfer.selector);
        token.mint(ADDRESS3, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();
        assertEq(token.balanceOf(ADDRESS1), 10);
    }
}
