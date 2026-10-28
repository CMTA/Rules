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
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";

/**
 * @title RuleIssuanceCap with a RuleEngine set at CMTAT v3.0.0 deployment
 * @notice The gap-free order: the engine is passed in the token constructor, the rule is bound to the engine
 * and added, and the token is bound to the engine last. Until then every mint, the admin's included, reverts,
 * so no mint escapes the issuance counter.
 */
contract RuleIssuanceCapV300DeploymentTest is Test, HelperContract {
    uint256 private constant CAP = 100;
    uint8 private constant CODE_ISSUANCE_CAP = 86;

    function _deployTokenWithEngine(address engine) private returns (CMTATStandalone) {
        return new CMTATStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(engine), ISnapshotEngine(ZERO_ADDRESS), IERC1643(ZERO_ADDRESS))
        );
    }

    function testRuleEngineInConstructorLeavesNoUncountedWindow() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        CMTATStandalone token = _deployTokenWithEngine(address(engine));

        // Engine set, token not bound to it yet: the admin cannot mint.
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        rule.bindToken(address(engine));
        engine.addRule(IRule(address(rule)));
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        // Last step: the engine accepts the token. From the first mint that can succeed, the rule counts it.
        engine.bindToken(address(token));
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, TRANSFER_OK);
        assertEq(headroom, CAP);

        token.mint(ADDRESS1, CAP);
        token.burn(ADDRESS1, CAP);
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_ISSUANCE_CAP);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        token.mint(ADDRESS1, 1);
        vm.stopPrank();
        assertEq(rule.totalIssued(), CAP);
        assertEq(token.totalSupply(), 0);
    }

    /// @notice A rule not yet bound reports code 85 on every view: the token would reject every operation.
    function testUnboundRuleReportsCode85() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        CMTATStandalone token = _deployTokenWithEngine(address(engine));
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        vm.stopPrank();
        (uint8 code,) = rule.remainingMintable();
        assertEq(code, CODE_RULE_NOT_BOUND);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_RULE_NOT_BOUND);
    }
}
