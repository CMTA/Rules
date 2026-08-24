// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";
import {MockERC20WithTransferContext} from "src/mocks/MockERC20WithTransferContext.sol";
import {MockERC20TransferFromFalse} from "src/mocks/MockERC20TransferFromFalse.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RuleConditionalTransferLightApproveAndTransfer is Test, HelperContract {
    RuleConditionalTransferLight private rule;
    MockERC20WithTransferContext private token;

    function setUp() public {
        token = new MockERC20WithTransferContext("Mock", "MOCK");

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));
        vm.stopPrank();

        token.setRule(address(rule));
        token.mint(ADDRESS1, 100);
    }

    function testApproveAndTransferIfAllowed() public {
        vm.prank(ADDRESS1);
        token.approve(address(rule), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);

        assertEq(token.balanceOf(ADDRESS1), 90);
        assertEq(token.balanceOf(ADDRESS2), 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 0);
    }

    /*//////////////////////////////////////////////////////////////
              NM-17: THE APPROVAL MUST BE CONSUMED
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice A token that never calls back leaves the helper's approval unconsumed, and the helper
     *         must reject that rather than complete.
     * @dev THE REGRESSION. The helper inverts CEI on purpose: it records the approval BEFORE
     *      `safeTransferFrom` so the token's compliance callback can consume it. Nothing used to
     *      verify the callback happened. A plain ERC-20 bound with `bindToken`, or a RuleEngine never
     *      bound or since unbound, therefore completed the transfer and left the approval standing —
     *      indistinguishable from an operator-created one, and enough to authorise a later,
     *      never-approved transfer of exactly `(from, to, value)`.
     */
    function testRevertsWhenTheTokenDoesNotCallBack() public {
        MockERC20WithTransferContext silentToken = new MockERC20WithTransferContext("Silent", "SIL");
        // Deliberately NOT `setRule`: this token moves value and tells nobody.
        silentToken.mint(ADDRESS1, 100);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLight silentRule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        silentRule.bindToken(address(silentToken));
        vm.stopPrank();

        vm.prank(ADDRESS1);
        silentToken.approve(address(silentRule), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleConditionalTransferLight_ApprovalNotConsumed.selector,
                address(silentToken),
                ADDRESS1,
                ADDRESS2,
                uint256(10)
            )
        );
        silentRule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);

        // The whole call reverted, so no residual approval and no value moved.
        assertEq(silentRule.approvedCount(ADDRESS1, ADDRESS2, 10), 0, "no approval may be left behind");
        assertEq(silentToken.balanceOf(ADDRESS1), 100, "the transfer was rolled back");
        assertEq(silentToken.balanceOf(ADDRESS2), 0);
    }

    /**
     * @notice The post-condition compares against the count BEFORE the helper ran, not against zero.
     * @dev An operator may legitimately hold outstanding approvals for the same tuple. The helper adds
     *      one, the callback consumes one, and the pre-existing approvals must survive untouched.
     */
    function testPreExistingApprovalsSurviveTheHelper() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);
        vm.stopPrank();
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 2);

        vm.prank(ADDRESS1);
        token.approve(address(rule), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);

        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 2, "the operator's own approvals are untouched");
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    /// @notice The normal direct-binding flow still works: the callback consumes exactly one approval.
    function testDirectBindingFlowStillConsumesExactlyOne() public {
        vm.prank(ADDRESS1);
        token.approve(address(rule), 20);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);
        rule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);
        vm.stopPrank();

        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 0);
        assertEq(token.balanceOf(ADDRESS2), 20);
    }

    function testApproveAndTransferIfAllowedRevertsWhenNoTokenBound() public {
        RuleConditionalTransferLight freshRule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleConditionalTransferLight_TokenNotBound.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        freshRule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);
    }

    function testApproveAndTransferIfAllowedRevertsOnInsufficientAllowance() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleConditionalTransferLight_InsufficientAllowance.selector, address(token), ADDRESS1, 0, 10
            )
        );
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);
    }

    function testApproveAndTransferIfAllowedRevertsOnTransferFailure() public {
        MockERC20TransferFromFalse failingToken = new MockERC20TransferFromFalse();
        failingToken.setAllowance(ADDRESS1, address(rule), 10);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindToken(address(token));
        rule.bindToken(address(failingToken));
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(failingToken)));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);
    }
}
