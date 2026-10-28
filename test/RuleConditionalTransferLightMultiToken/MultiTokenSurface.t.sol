// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";

/**
 * @title MultiTokenSurface
 * @notice Closes the residual coverage gap on `RuleConditionalTransferLightMultiToken`: the
 *         `created` / `destroyed` compliance hooks, `cancelTransferApproval`, the restriction-code
 *         metadata, and the spender-aware read views.
 */
contract MultiTokenSurface is Test, HelperContract {
    /// @dev Redeclared locally: `HelperContract` inherits the single-token invariant storage, whose
    ///      constants clash with the multi-token variant's.
    error RuleConditionalTransferLightMultiToken_TransferApprovalNotFound();

    /// @dev Redeclared for the same reason as the error above: the single-token `TransferApproved`
    ///      inherited via `HelperContract` has a different signature (no `token` parameter).
    event TransferApproved(
        address indexed token, address indexed from, address indexed to, uint256 value, uint256 count
    );

    uint8 private constant CODE_NOT_APPROVED = 46;

    RuleConditionalTransferLightMultiToken private rule;

    function setUp() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    RESTRICTION-CODE METADATA
    //////////////////////////////////////////////////////////////*/

    function test_CanReturnTransferRestrictionCode() public view {
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_NOT_APPROVED));
        assertFalse(rule.canReturnTransferRestrictionCode(CODE_NONEXISTENT));
    }

    /**
     * @notice The approval count carried by {TransferApproved} must be the post-increment value.
     * @dev `_approveTransfer` keeps the new count in a local rather than reading the slot back after
     *      storing it. Equivalent by construction, but nothing else asserts the event payload, so
     *      this pins it: a second approval of the same transfer must report 2, not 1 and not 0.
     */
    function test_ApproveTransferEmitsPostIncrementCount() public {
        vm.expectEmit(true, true, true, true);
        emit TransferApproved(ADDRESS1, ADDRESS2, ADDRESS3, 10, 1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);

        vm.expectEmit(true, true, true, true);
        emit TransferApproved(ADDRESS1, ADDRESS2, ADDRESS3, 10, 2);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);

        // The event and the getter must agree.
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, ADDRESS3, 10), 2);
    }

    function test_MessageForTransferRestriction() public view {
        assertEq(
            rule.messageForTransferRestriction(CODE_NOT_APPROVED), "ConditionalTransfer: The request is not approved"
        );
        assertEq(rule.messageForTransferRestriction(CODE_NONEXISTENT), TEXT_CODE_NOT_FOUND);
    }

    /*//////////////////////////////////////////////////////////////
                    MINT / BURN COMPLIANCE HOOKS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice `created` / `destroyed` are exempt from approval consumption (mint/burn), so they
     *         succeed without any approval and leave `approvalCounts` untouched.
     */
    function test_CreatedAndDestroyedAreExemptFromApprovalConsumption() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, ADDRESS3, 10), 1);

        vm.startPrank(ADDRESS1); // the bound token
        rule.created(ADDRESS2, 10);
        rule.destroyed(ADDRESS2, 10);
        vm.stopPrank();

        // The approval was NOT consumed by the mint/burn hooks.
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, ADDRESS3, 10), 1);
    }

    /// @notice Only the bound token may call the mint/burn hooks.
    function test_CreatedAndDestroyedRejectUnboundCaller() public {
        vm.prank(ATTACKER);
        vm.expectRevert();
        rule.created(ADDRESS2, 10);

        vm.prank(ATTACKER);
        vm.expectRevert();
        rule.destroyed(ADDRESS2, 10);
    }

    /*//////////////////////////////////////////////////////////////
                        CANCEL APPROVAL
    //////////////////////////////////////////////////////////////*/

    function test_CancelTransferApprovalDecrementsByOne() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, ADDRESS3, 10), 2);

        rule.cancelTransferApproval(ADDRESS1, ADDRESS2, ADDRESS3, 10);
        vm.stopPrank();

        // Exactly one removed (contrast with `resetApproval`, which clears them all).
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, ADDRESS3, 10), 1);
    }

    function test_CancelTransferApprovalRevertsWhenNoneExists() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleConditionalTransferLightMultiToken_TransferApprovalNotFound.selector);
        rule.cancelTransferApproval(ADDRESS1, ADDRESS2, ADDRESS3, 10);
    }

    function test_CancelTransferApprovalIsApproverOnly() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);

        vm.prank(ATTACKER);
        vm.expectRevert();
        rule.cancelTransferApproval(ADDRESS1, ADDRESS2, ADDRESS3, 10);

        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, ADDRESS3, 10), 1);
    }

    /*//////////////////////////////////////////////////////////////
                    SPENDER-AWARE READ VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The spender-aware ERC-1404 / ERC-7551 views ignore the spender and delegate to the
     *         caller-keyed `detectTransferRestriction`, so they carry the same caller dependence.
     */
    function test_SpenderAwareViewsDelegateToTheCallerKeyedView() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);

        // Called BY the bound token: approved.
        vm.prank(ADDRESS1);
        assertEq(rule.detectTransferRestrictionFrom(ATTACKER, ADDRESS2, ADDRESS3, 10), TRANSFER_OK);
        vm.prank(ADDRESS1);
        assertTrue(rule.canTransferFrom(ATTACKER, ADDRESS2, ADDRESS3, 10));

        // Called by anyone else: fail-closed (use the `…ForToken` views instead).
        vm.prank(ATTACKER);
        assertEq(rule.detectTransferRestrictionFrom(ATTACKER, ADDRESS2, ADDRESS3, 10), CODE_NOT_APPROVED);
        vm.prank(ATTACKER);
        assertFalse(rule.canTransferFrom(ATTACKER, ADDRESS2, ADDRESS3, 10));
    }
}
