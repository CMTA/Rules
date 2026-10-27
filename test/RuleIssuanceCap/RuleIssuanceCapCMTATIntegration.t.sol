// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {ICMTATConstructor, CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {TokenBindingModuleInvariantStorage} from "RuleEngine/modules/library/TokenBindingModuleInvariantStorage.sol";

/**
 * @title RuleIssuanceCap on the current CMTAT (>= v3.3)
 * @notice Mints reach the rule on the 4-argument path with the minter as spender; the spender is ignored.
 */
contract RuleIssuanceCapCMTATIntegration is Test, HelperContract {
    uint256 private constant CAP = 100;
    RuleIssuanceCap private rule;

    function _setUpTopology(bool viaEngine) private {
        cmtatContract = new CMTATDeployment().cmtat();
        rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(cmtatContract), CAP, 0);
        address caller = address(cmtatContract);
        address target = address(rule);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        if (viaEngine) {
            ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(cmtatContract));
            ruleEngineMock.addRule(rule);
            caller = address(ruleEngineMock);
            target = address(ruleEngineMock);
        }
        rule.bindToken(caller);
        cmtatContract.setRuleEngine(IRuleEngine(target));
        cmtatContract.mint(ADDRESS1, 60);
        vm.stopPrank();
    }

    function _burnDoesNotRestoreTheCap() private {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.burn(ADDRESS1, 30);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransferFrom.selector);
        cmtatContract.mint(ADDRESS2, 41);
        cmtatContract.mint(ADDRESS2, 40);
        vm.stopPrank();
        assertEq(rule.totalIssued(), CAP);
        assertEq(cmtatContract.totalSupply(), 70);
    }

    function testBurnDoesNotRestoreTheCapDirect() public {
        _setUpTopology(false);
        _burnDoesNotRestoreTheCap();
    }

    function testBurnDoesNotRestoreTheCapViaRuleEngine() public {
        _setUpTopology(true);
        _burnDoesNotRestoreTheCap();
    }

    function testTokenViewReportsTheIssuanceCode() public {
        _setUpTopology(true);
        assertEq(cmtatContract.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 40), TRANSFER_OK);
        assertEq(cmtatContract.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 41), 71);
        // The burn frees live-supply room (supply 30) but not issuance room: still 71, not OK.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.burn(ADDRESS1, 30);
        assertEq(cmtatContract.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 41), 71);
    }

    /// @dev A CMTAT whose RuleEngine is set in the constructor, as `CMTATDeployment` does with `address(0)`.
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

    /// @notice The documented gap-free setup: the engine is set at token deployment and binds the token last,
    /// so every mint, even the admin's, reverts until the cap rule is in place. No mint can escape the counter.
    function testDeploymentWithEngineInConstructorLeavesNoUncountedWindow() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        CMTATStandardStandalone token = _deployTokenWithEngine(address(engine));

        // Engine set, token not yet bound to it: the admin cannot mint.
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        rule.bindToken(address(engine));
        engine.addRule(rule);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        // Last step: the engine accepts the token. From the first possible mint, the rule counts.
        engine.bindToken(address(token));
        token.mint(ADDRESS1, CAP);
        token.burn(ADDRESS1, CAP);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransferFrom.selector);
        token.mint(ADDRESS1, 1);
        vm.stopPrank();
        assertEq(rule.totalIssued(), CAP);
    }

    /// @notice Same order with a dedicated minter granted `MINTER_ROLE` before the engine binds the token:
    /// the role alone is not enough, its mint reverts until the token is bound, then the rule counts it.
    function testDeploymentWithEngineInConstructorBlocksGrantedMinter() public {
        address minter = address(0x4D1);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        CMTATStandardStandalone token = _deployTokenWithEngine(address(engine));
        rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        rule.bindToken(address(engine));
        engine.addRule(rule);
        token.grantRole(keccak256("MINTER_ROLE"), minter);
        vm.stopPrank();

        vm.prank(minter);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);
        assertEq(token.totalSupply(), 0);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        engine.bindToken(address(token));
        vm.prank(minter);
        token.mint(ADDRESS1, CAP);
        vm.prank(minter);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransferFrom.selector);
        token.mint(ADDRESS1, 1);
        assertEq(rule.totalIssued(), CAP);
    }
}
