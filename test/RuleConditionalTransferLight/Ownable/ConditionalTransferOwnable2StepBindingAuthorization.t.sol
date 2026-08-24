// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    RuleConditionalTransferLightOwnable2Step
} from "src/rules/operation/RuleConditionalTransferLightOwnable2Step.sol";
import {
    RuleConditionalTransferLightMultiTokenOwnable2Step
} from "src/rules/operation/RuleConditionalTransferLightMultiTokenOwnable2Step.sol";

/**
 * @notice Owner-only authorization on the two Ownable2Step conditional-transfer variants.
 * @dev These hooks had no coverage before: the only test naming
 *      `RuleConditionalTransferLightMultiTokenOwnable2Step` was an ERC-165 support check, which never
 *      reaches an access-control path. Three concrete overrides were therefore unexercised —
 *      `_authorizeTokenBindingChange` on the single-token variant, and `_onlyComplianceManager`
 *      plus `_authorizeTransferApproval` on the multi-token one.
 *
 *      Note which entrypoint reaches which hook. `RuleConditionalTransferLightBase` overrides
 *      `bindToken` with its own `onlyTokenBindingManager` modifier, so on the single-token rule the
 *      only route to `_authorizeTokenBindingChange` is the inherited `unbindToken`.
 */
contract ConditionalTransferOwnable2StepBindingAuthorizationTest is Test {
    address constant OWNER = address(0xA11CE);
    address constant ATTACKER = address(0xBAD);
    address constant TOKEN = address(0x7);
    address constant FROM = address(0x11);
    address constant TO = address(0x12);
    uint256 constant VALUE = 100;

    RuleConditionalTransferLightOwnable2Step single;
    RuleConditionalTransferLightMultiTokenOwnable2Step multi;

    function setUp() public {
        single = new RuleConditionalTransferLightOwnable2Step(OWNER);
        multi = new RuleConditionalTransferLightMultiTokenOwnable2Step(OWNER);
    }

    /*//////////////////////////////////////////////////////////////
              SINGLE TOKEN -- _authorizeTokenBindingChange
    //////////////////////////////////////////////////////////////*/

    function testSingleUnbindTokenRejectsNonOwner() public {
        vm.prank(OWNER);
        single.bindToken(TOKEN);

        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        single.unbindToken(TOKEN);
    }

    function testSingleUnbindTokenAllowsOwner() public {
        vm.startPrank(OWNER);
        single.bindToken(TOKEN);
        assertTrue(single.isTokenBound(TOKEN));
        single.unbindToken(TOKEN);
        vm.stopPrank();

        assertFalse(single.isTokenBound(TOKEN));
    }

    /*//////////////////////////////////////////////////////////////
                 MULTI TOKEN -- _onlyComplianceManager
    //////////////////////////////////////////////////////////////*/

    function testMultiBindTokenRejectsNonOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        multi.bindToken(TOKEN);
    }

    function testMultiBindTokenAllowsOwner() public {
        vm.prank(OWNER);
        multi.bindToken(TOKEN);
        assertTrue(multi.isTokenBound(TOKEN));
    }

    function testMultiUnbindTokenRejectsNonOwner() public {
        vm.prank(OWNER);
        multi.bindToken(TOKEN);

        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        multi.unbindToken(TOKEN);
    }

    /*//////////////////////////////////////////////////////////////
                MULTI TOKEN -- _authorizeTransferApproval
    //////////////////////////////////////////////////////////////*/

    function testMultiApproveTransferRejectsNonOwner() public {
        vm.prank(OWNER);
        multi.bindToken(TOKEN);

        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        multi.approveTransfer(TOKEN, FROM, TO, VALUE);
    }

    function testMultiApproveTransferAllowsOwner() public {
        vm.startPrank(OWNER);
        multi.bindToken(TOKEN);
        multi.approveTransfer(TOKEN, FROM, TO, VALUE);
        vm.stopPrank();

        assertEq(multi.approvedCount(TOKEN, FROM, TO, VALUE), 1);
    }
}
