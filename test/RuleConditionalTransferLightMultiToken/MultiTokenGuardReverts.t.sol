// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {MockERC20WithTransferContext} from "src/mocks/MockERC20WithTransferContext.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";

/**
 * @title MultiTokenGuardReverts
 * @notice The reject side of every guard in {RuleConditionalTransferLightMultiTokenBase}.
 * @dev These four branches were the only uncovered ones in `src/` — each guard's accept path was
 *      exercised, its `require` never taken. A rule whose whole purpose is to refuse transfers needs
 *      its refusals asserted, not just its permissions: a guard that has never been observed to
 *      reject is a guard nobody has tested.
 */
contract MultiTokenGuardReverts is Test, HelperContract {
    /// @dev Re-declared locally: `HelperContract` cannot inherit the multi-token invariant storage
    ///      alongside the single-token one (`OPERATOR_ROLE` and the code constants clash).
    error RuleConditionalTransferLightMultiToken_InvalidToken();
    error RuleConditionalTransferLightMultiToken_InsufficientAllowance(
        address token, address from, uint256 allowance, uint256 value
    );
    error RuleConditionalTransferLightMultiToken_TransferExecutorUnauthorized(address account);

    RuleConditionalTransferLightMultiToken private rule;
    MockERC20WithTransferContext private boundToken;
    MockERC20WithTransferContext private strangerToken;

    function setUp() public {
        boundToken = new MockERC20WithTransferContext("Bound", "BND");
        strangerToken = new MockERC20WithTransferContext("Stranger", "STR");

        rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(boundToken));
        boundToken.setRule(address(rule));

        boundToken.mint(ADDRESS1, 100);
        strangerToken.mint(ADDRESS1, 100);
    }

    /// @notice L137: `approveAndTransferIfAllowed` refuses a token that was never bound.
    function testApproveAndTransferRejectsAnUnboundToken() public {
        vm.prank(ADDRESS1);
        strangerToken.approve(address(rule), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleConditionalTransferLightMultiToken_InvalidToken.selector);
        rule.approveAndTransferIfAllowed(address(strangerToken), ADDRESS1, ADDRESS2, 10);
    }

    /// @notice L143: `approveAndTransferIfAllowed` refuses when the holder's allowance is short.
    function testApproveAndTransferRejectsAnInsufficientAllowance() public {
        vm.prank(ADDRESS1);
        boundToken.approve(address(rule), 4); // less than the 10 requested

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleConditionalTransferLightMultiToken_InsufficientAllowance.selector,
                address(boundToken),
                ADDRESS1,
                uint256(4),
                uint256(10)
            )
        );
        rule.approveAndTransferIfAllowed(address(boundToken), ADDRESS1, ADDRESS2, 10);

        // The rejection is total: no approval was recorded and no value moved.
        assertEq(rule.approvedCount(address(boundToken), ADDRESS1, ADDRESS2, 10), 0);
        assertEq(boundToken.balanceOf(ADDRESS2), 0);
    }

    /// @notice L371: `cancelTransferApproval` refuses a token that was never bound.
    function testCancelTransferApprovalRejectsAnUnboundToken() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleConditionalTransferLightMultiToken_InvalidToken.selector);
        rule.cancelTransferApproval(address(strangerToken), ADDRESS1, ADDRESS2, 10);
    }

    /// @notice L440: the execution hook refuses a caller that is not a bound token.
    /// @dev This rule is direct-binding only, so the executor check *is* the token check: approval
    ///      consumption is keyed on `msg.sender`. An unbound caller must never consume one.
    function testTransferredRejectsACallerThatIsNotABoundToken() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(boundToken), ADDRESS1, ADDRESS2, 10);

        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleConditionalTransferLightMultiToken_TransferExecutorUnauthorized.selector, ATTACKER
            )
        );
        rule.transferred(ADDRESS1, ADDRESS2, 10);

        // The approval survives the rejected attempt.
        assertEq(rule.approvedCount(address(boundToken), ADDRESS1, ADDRESS2, 10), 1);
    }
}
