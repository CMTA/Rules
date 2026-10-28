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
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";

/**
 * @title RuleConditionalTransferLight on the current CMTAT (>= v3.3), set at or after deployment
 * @notice The rule set directly (in the constructor or with `setRuleEngine`) and a RuleEngine in the constructor.
 * Until the rule is bound to its caller every mint and transfer reverts; mint and burn then need no approval.
 */
contract RuleConditionalTransferLightCMTATDeployment is Test, HelperContract {
    RuleConditionalTransferLight private rule;

    function setUp() public {
        rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
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

    /// @dev An approved transfer, an unapproved one, the operator helper and a burn, on a bound setup.
    function _assertApprovalFlow(CMTATStandardStandalone token) private {
        vm.prank(ADDRESS1);
        vm.expectRevert(TransferNotApproved.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);
        assertEq(token.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 0);

        vm.prank(ADDRESS1);
        token.approve(address(rule), 5);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 5);
        assertEq(token.balanceOf(ADDRESS2), 15);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 5), 0);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burn(ADDRESS2, 15);
        assertEq(token.totalSupply(), 85);
    }

    /// @notice Rule in the constructor: code 85 and a reverted mint until `bindToken`.
    function testRuleInConstructorBlocksUntilBound() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(token.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_RULE_NOT_BOUND);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(RuleConditionalTransferLight_TransferExecutorUnauthorized.selector, address(token))
        );
        token.mint(ADDRESS1, 100);
        rule.bindToken(address(token));
        token.mint(ADDRESS1, 100);
        vm.stopPrank();

        _assertApprovalFlow(token);
    }

    /// @notice Rule set directly after deployment: bound first, then installed with `setRuleEngine`.
    function testRuleSetDirectlyAfterDeployment() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        CMTATStandardStandalone token = _deployToken(ZERO_ADDRESS);
        rule.bindToken(address(token));
        token.setRuleEngine(IRuleEngine(address(rule)));
        token.mint(ADDRESS1, 100);
        vm.stopPrank();

        _assertApprovalFlow(token);
    }

    /// @notice RuleEngine in the constructor: blocked until the engine binds the token AND the rule binds the engine.
    function testRuleEngineInConstructorBlocksUntilBothBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        engine.addRule(IRule(address(rule)));
        CMTATStandardStandalone token = _deployToken(address(engine));

        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 100);

        engine.bindToken(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(RuleConditionalTransferLight_TransferExecutorUnauthorized.selector, address(engine))
        );
        token.mint(ADDRESS1, 100);

        rule.bindToken(address(token));
        rule.bindRuleEngine(address(engine));
        token.mint(ADDRESS1, 100);
        vm.stopPrank();

        _assertApprovalFlow(token);
    }
}
