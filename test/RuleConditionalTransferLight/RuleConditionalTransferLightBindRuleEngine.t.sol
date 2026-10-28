// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";

/**
 * @title RuleConditionalTransferLightBindRuleEngine
 * @notice Covers the split binding introduced by improvement I-5 (finding F-3, threat `CTL-1`).
 * @dev `bindToken` used to serve two conflicting roles at once — the ERC-20 target of
 *      `approveAndTransferIfAllowed` AND the authorized caller of `transferred`. Behind a RuleEngine
 *      those are two different addresses, and the single slot could only hold one, so the helper was
 *      unusable. `bindRuleEngine` splits them: bind the token as the ERC-20 target, bind the engine as
 *      an additional authorized caller, and the helper works in both topologies.
 */
contract RuleConditionalTransferLightBindRuleEngine is Test, HelperContract {
    RuleConditionalTransferLight private rule;

    function setUp() public {
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(cmtatContract));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(rule);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.setRuleEngine(ruleEngineMock);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.grantRole(keccak256("MINTER_ROLE"), DEFAULT_ADMIN_ADDRESS);
    }

    /// @dev The supported RuleEngine wiring: token bound as the ERC-20, engine bound as a caller.
    function _bindBoth() private {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(cmtatContract));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindRuleEngine(address(ruleEngineMock));
    }

    /*//////////////////////////////////////////////////////////////
                    THE FIX: BOTH TOPOLOGIES WORK
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The whole point of I-5: with the token AND the engine bound,
     *         `approveAndTransferIfAllowed` now works end-to-end behind a RuleEngine.
     */
    function test_ApproveAndTransferIfAllowedWorksBehindRuleEngine() public {
        _bindBoth();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, 100);
        vm.prank(ADDRESS1);
        cmtatContract.approve(address(rule), 1000);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        assertTrue(rule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10));

        assertEq(cmtatContract.balanceOf(ADDRESS2), 10);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 90);
        // The approval recorded by the helper was consumed by the engine's callback.
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 0);
    }

    /**
     * @notice Ordinary transfers also work: the engine is now an authorized executor, so the
     *         approval it consumes is the one the operator recorded.
     */
    function test_OperatorApprovedTransferIsConsumedByTheEngine() public {
        _bindBoth();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, 100);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 25);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 25), 1);

        vm.prank(ADDRESS1);
        cmtatContract.transfer(ADDRESS2, 25);

        assertEq(cmtatContract.balanceOf(ADDRESS2), 25);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 25), 0);
    }

    /**
     * @notice An unapproved transfer is still rejected through the engine.
     */
    function test_UnapprovedTransferStillRejectedBehindRuleEngine() public {
        _bindBoth();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, 100);

        vm.prank(ADDRESS1);
        vm.expectRevert(TransferNotApproved.selector);
        cmtatContract.transfer(ADDRESS2, 25);
    }

    /**
     * @notice Direct binding still works unchanged: a token bound alone is its own executor.
     */
    function test_DirectBindingStillWorks() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);

        assertTrue(rule.isTransferExecutor(ADDRESS1));
        assertEq(rule.ruleEngine(), ZERO_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS2, ADDRESS3, 10);
        vm.prank(ADDRESS1);
        rule.transferred(ADDRESS2, ADDRESS3, 10);
        assertEq(rule.approvedCount(ADDRESS2, ADDRESS3, 10), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Without `bindRuleEngine`, the engine remains unauthorized — the old failure mode.
     *         This is what makes the new binding necessary rather than cosmetic.
     */
    function test_EngineUnauthorizedUntilBound() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(cmtatContract));

        assertFalse(rule.isTransferExecutor(address(ruleEngineMock)));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleConditionalTransferLight_TransferExecutorUnauthorized.selector, address(ruleEngineMock)
            )
        );
        cmtatContract.mint(ADDRESS1, 100);

        // Binding the engine unblocks it.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindRuleEngine(address(ruleEngineMock));
        assertTrue(rule.isTransferExecutor(address(ruleEngineMock)));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, 100);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 100);
    }

    /**
     * @notice An arbitrary address is never a transfer executor.
     */
    function test_ArbitraryCallerIsNotExecutor() public {
        _bindBoth();

        assertFalse(rule.isTransferExecutor(ATTACKER));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);

        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(RuleConditionalTransferLight_TransferExecutorUnauthorized.selector, ATTACKER)
        );
        rule.transferred(ADDRESS1, ADDRESS2, 10);

        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        BINDING LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    function test_BindRuleEngineGuards() public {
        // zero address rejected
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleConditionalTransferLight_RuleEngineAddressZeroNotAllowed.selector);
        rule.bindRuleEngine(ZERO_ADDRESS);

        // second binding rejected until unbound
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindRuleEngine(address(ruleEngineMock));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleConditionalTransferLight_RuleEngineAlreadyBound.selector);
        rule.bindRuleEngine(ATTACKER);

        // unbind, then rebind
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindRuleEngine();
        assertEq(rule.ruleEngine(), ZERO_ADDRESS);
        assertFalse(rule.isTransferExecutor(address(ruleEngineMock)));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindRuleEngine(ATTACKER);
        assertEq(rule.ruleEngine(), ATTACKER);
    }

    function test_UnbindRuleEngineRevertsWhenNoneBound() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleConditionalTransferLight_RuleEngineNotBound.selector);
        rule.unbindRuleEngine();
    }

    function test_BindRuleEngineIsComplianceManagerOnly() public {
        vm.prank(ATTACKER);
        vm.expectRevert();
        rule.bindRuleEngine(address(ruleEngineMock));

        _bindBoth();

        vm.prank(ATTACKER);
        vm.expectRevert();
        rule.unbindRuleEngine();

        assertEq(rule.ruleEngine(), address(ruleEngineMock));
    }
}
