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
import {RuleMaxBalance} from "src/rules/validation/deployment/RuleMaxBalance.sol";
import {
    RuleMaxBalanceInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleMaxBalanceInvariantStorage.sol";

/**
 * @title RuleMaxBalance with a RuleEngine set at CMTAT v3.0.0 deployment
 * @notice The rule needs the token address, so it cannot be passed in the token constructor itself; a
 * RuleEngine can, and binding the token last keeps every mint and transfer screened.
 */
contract RuleMaxBalanceV300DeploymentTest is Test, HelperContract {
    uint256 private constant CAP = 100;

    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        CMTATStandalone token = new CMTATStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(
                IRuleEngine(address(engine)), ISnapshotEngine(ZERO_ADDRESS), IERC1643(ZERO_ADDRESS)
            )
        );
        RuleMaxBalance rule = new RuleMaxBalance(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
        engine.addRule(IRule(address(rule)));

        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        engine.bindToken(address(token));
        (uint8 code, uint256 headroom) = rule.remainingCapacity(ADDRESS1);
        assertEq(code, TRANSFER_OK);
        assertEq(headroom, CAP);
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, CAP + 1), 82);

        token.mint(ADDRESS1, CAP);
        token.mint(ADDRESS2, CAP);
        vm.expectPartialRevert(RuleMaxBalanceInvariantStorage.RuleMaxBalance_InvalidTransfer.selector);
        token.mint(ADDRESS1, 1);
        vm.stopPrank();

        // A holder at the cap cannot receive more by transfer either; the sender is never screened.
        vm.prank(ADDRESS1);
        vm.expectPartialRevert(RuleMaxBalanceInvariantStorage.RuleMaxBalance_InvalidTransfer.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 1);
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS3, 40);
        assertEq(token.balanceOf(ADDRESS3), 40);
    }

    /// @notice The rule cannot be deployed before its token: the constructor requires a contract address.
    function testRuleCannotBeDeployedBeforeTheToken() public {
        vm.expectRevert(RuleMaxBalanceInvariantStorage.RuleMaxBalance_TokenAddressZeroNotAllowed.selector);
        new RuleMaxBalance(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, CAP);
    }
}
