// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {MockERC20WithTransferContext} from "src/mocks/MockERC20WithTransferContext.sol";

contract RuleConditionalTransferLightMultiTokenTest is Test, HelperContract {
    /// @dev Re-declared locally: `HelperContract` cannot inherit the multi-token invariant storage
    ///      alongside the single-token one (`OPERATOR_ROLE` and the code constants clash), which is the
    ///      same reason `MultiTokenSurface.t.sol` re-declares its errors.
    error RuleConditionalTransferLightMultiToken_ApprovalNotConsumed(
        address token, address from, address to, uint256 value
    );

    RuleConditionalTransferLightMultiToken private rule;
    MockERC20WithTransferContext private tokenA;
    MockERC20WithTransferContext private tokenB;

    function setUp() public {
        tokenA = new MockERC20WithTransferContext("Token A", "TKNA");
        tokenB = new MockERC20WithTransferContext("Token B", "TKNB");

        rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(tokenA));
        rule.bindToken(address(tokenB));
        vm.stopPrank();

        tokenA.setRule(address(rule));
        tokenB.setRule(address(rule));

        tokenA.mint(ADDRESS1, 100);
        tokenB.mint(ADDRESS1, 100);
    }

    /**
     * @notice NM-17: a bound token that never calls back leaves the helper's approval unconsumed.
     * @dev Same inverted-CEI shape as the single-token rule: `approveAndTransferIfAllowed` records the
     *      approval before `safeTransferFrom` so the compliance callback can consume it, and nothing
     *      used to check the callback happened. Here the token is bound but has no rule set, so it
     *      moves value silently — the helper must now reject rather than complete and leave a
     *      spendable approval for `(tokenC, from, to, value)`.
     */
    function testApproveAndTransferRevertsWhenTheTokenDoesNotCallBack() public {
        MockERC20WithTransferContext silentToken = new MockERC20WithTransferContext("Silent", "SIL");
        // Bound to the rule, but deliberately NOT `setRule`: it tells nobody.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(silentToken));
        silentToken.mint(ADDRESS1, 100);

        vm.prank(ADDRESS1);
        silentToken.approve(address(rule), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleConditionalTransferLightMultiToken_ApprovalNotConsumed.selector,
                address(silentToken),
                ADDRESS1,
                ADDRESS2,
                uint256(10)
            )
        );
        rule.approveAndTransferIfAllowed(address(silentToken), ADDRESS1, ADDRESS2, 10);

        assertEq(rule.approvedCount(address(silentToken), ADDRESS1, ADDRESS2, 10), 0, "no residual approval");
        assertEq(silentToken.balanceOf(ADDRESS1), 100, "the transfer was rolled back");
    }

    /// @notice NM-17: a token that does call back is unaffected, and the count is per-token.
    function testApproveAndTransferStillWorksAndIsPerToken() public {
        vm.prank(ADDRESS1);
        tokenA.approve(address(rule), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(address(tokenA), ADDRESS1, ADDRESS2, 10);

        assertEq(tokenA.balanceOf(ADDRESS2), 10);
        assertEq(rule.approvedCount(address(tokenA), ADDRESS1, ADDRESS2, 10), 0);
        assertEq(rule.approvedCount(address(tokenB), ADDRESS1, ADDRESS2, 10), 0, "token B untouched");
    }

    function testApprovalForTokenADoesNotAuthorizeTokenB() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(tokenA), ADDRESS1, ADDRESS2, 10);

        vm.prank(ADDRESS1);
        tokenA.transfer(ADDRESS2, 10);

        assertEq(tokenA.balanceOf(ADDRESS1), 90);
        assertEq(tokenA.balanceOf(ADDRESS2), 10);

        vm.expectRevert();
        vm.prank(ADDRESS1);
        tokenB.transfer(ADDRESS2, 10);
    }

    function testApproveAndTransferIfAllowedUsesTokenScopedApproval() public {
        vm.prank(ADDRESS1);
        tokenA.approve(address(rule), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(address(tokenA), ADDRESS1, ADDRESS2, 10);

        assertEq(tokenA.balanceOf(ADDRESS1), 90);
        assertEq(tokenA.balanceOf(ADDRESS2), 10);
        assertEq(rule.approvedCount(address(tokenA), ADDRESS1, ADDRESS2, 10), 0);
        assertEq(rule.approvedCount(address(tokenB), ADDRESS1, ADDRESS2, 10), 0);
    }

    function testApproveTransferRevertsForUnboundToken() public {
        vm.expectRevert();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }
}
