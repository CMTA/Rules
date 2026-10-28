// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {ICMTATConstructor, CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {TokenBindingModuleInvariantStorage} from "RuleEngine/modules/library/TokenBindingModuleInvariantStorage.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";

/**
 * @title RuleMintAllowance deployment orders on CMTAT v3.3
 * @notice The rule needs no token address, so it (or a RuleEngine) can be passed in the token constructor. It
 * must then be bound to its caller: until that binding every mint and transfer reverts, so neither order
 * leaves an unscreened window. Also covers the rule set directly on the token after deployment.
 */
contract RuleMintAllowanceCMTATDeploymentTest is Test, HelperContract {
    address private constant MINTER = address(0x4D1);
    uint256 private constant QUOTA = 100;
    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");

    RuleMintAllowance private rule;

    function _deployTokenWithEngine(address engine) private returns (CMTATStandardStandalone) {
        return new CMTATStandardStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(engine))
        );
    }

    /// @dev Once the rule is bound: the quota is debited, enforced, and the 3-argument views do not see it.
    function _assertQuotaEnforced(CMTATStandardStandalone token) private {
        assertEq(token.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, QUOTA), TRANSFER_OK);
        assertEq(
            token.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, QUOTA + 1),
            CODE_MINTER_ALLOWANCE_EXCEEDED
        );
        // Not authoritative: the 3-argument view has no minter and answers OK.
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, QUOTA + 1), TRANSFER_OK);

        vm.prank(MINTER);
        token.mint(ADDRESS1, QUOTA);
        assertEq(rule.mintAllowance(MINTER), 0);
        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(RuleMintAllowance_AllowanceExceeded.selector, address(rule), MINTER, 0, 1)
        );
        token.mint(ADDRESS1, 1);

        // The default admin is not exempt: without a quota of its own, its mint is rejected too.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMintAllowance_AllowanceExceeded.selector, address(rule), DEFAULT_ADMIN_ADDRESS, 0, 1
            )
        );
        token.mint(ADDRESS1, 1);

        // Transfers and burns are not tracked.
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 10);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burn(ADDRESS2, 10);
        assertEq(token.totalSupply(), QUOTA - 10);
    }

    function testRuleInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, QUOTA);
        CMTATStandardStandalone token = _deployTokenWithEngine(address(rule));
        token.grantRole(MINTER_ROLE, MINTER);
        vm.stopPrank();

        // Rule set on the token but not bound to it: every view reports 85 and every mint reverts.
        assertEq(token.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 1), CODE_RULE_NOT_BOUND);
        vm.prank(MINTER);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));
        _assertQuotaEnforced(token);
    }

    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(engine));
        engine.addRule(rule);
        rule.setMintAllowance(MINTER, QUOTA);
        CMTATStandardStandalone token = _deployTokenWithEngine(address(engine));
        token.grantRole(MINTER_ROLE, MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        engine.bindToken(address(token));
        _assertQuotaEnforced(token);
    }

    function testRuleSetDirectlyAfterDeployment() public {
        CMTATStandardStandalone token = new CMTATDeployment().cmtat();
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));
        rule.setMintAllowance(MINTER, QUOTA);
        token.setRuleEngine(IRuleEngine(address(rule)));
        token.grantRole(MINTER_ROLE, MINTER);
        vm.stopPrank();
        _assertQuotaEnforced(token);
    }

    /// @notice A second binding reverts: the rule serves exactly one caller.
    function testSecondBindingReverts() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(0xE1));
        vm.expectRevert(RuleMintAllowance_TokenAlreadyBound.selector);
        rule.bindToken(address(0xE2));
        vm.stopPrank();
    }
}
