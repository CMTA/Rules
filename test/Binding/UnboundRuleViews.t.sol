// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";

/**
 * @title Unbound stateful rules report CODE_RULE_NOT_BOUND (85)
 * @notice `RuleIssuanceCap`, `RuleMintAllowance` and `RuleConditionalTransferLight` accept `transferred` only from a
 * bound caller, so until one is bound every operation reverts. Their views must say so instead of answering
 * "allowed". Once bound, the normal answers return; unbinding brings code 85 back.
 */
contract UnboundRuleViewsTest is Test {
    uint8 constant OK = 0;
    uint8 constant NOT_BOUND = 85;
    string constant NOT_BOUND_TEXT = "Rule not bound to a token or RuleEngine";
    address constant ADMIN = address(1);
    address constant CALLER = address(0xCA11);
    address constant ALICE = address(5);
    address constant BOB = address(6);

    /// @dev Every view of `rule` reports NOT_BOUND for a mint, a transfer and a burn.
    function _assertUnbound(address rule) internal view {
        (bool ok, bytes memory ret) = rule.staticcall(abi.encodeWithSignature("CODE_RULE_NOT_BOUND()"));
        assertTrue(ok);
        assertEq(abi.decode(ret, (uint8)), NOT_BOUND, "constant");
        IViews r = IViews(rule);
        assertEq(r.detectTransferRestriction(address(0), ALICE, 1), NOT_BOUND, "mint");
        assertEq(r.detectTransferRestriction(ALICE, BOB, 1), NOT_BOUND, "transfer");
        assertEq(r.detectTransferRestriction(ALICE, address(0), 1), NOT_BOUND, "burn");
        assertEq(r.detectTransferRestrictionFrom(ADMIN, address(0), ALICE, 1), NOT_BOUND, "mint, spender path");
        assertEq(r.detectTransferRestrictionFrom(BOB, ALICE, BOB, 1), NOT_BOUND, "transferFrom");
        assertFalse(r.canTransfer(ALICE, BOB, 1), "canTransfer");
        assertFalse(r.canTransferFrom(BOB, ALICE, BOB, 1), "canTransferFrom");
        assertTrue(r.canReturnTransferRestrictionCode(NOT_BOUND), "claims the code");
        assertEq(r.messageForTransferRestriction(NOT_BOUND), NOT_BOUND_TEXT, "message");
    }

    function testIssuanceCapUnboundThenBoundThenUnbound() public {
        RuleIssuanceCap rule = new RuleIssuanceCap(ADMIN, address(new TotalSupplyMock()), 100, 0);
        _assertUnbound(address(rule));
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, NOT_BOUND);
        assertEq(headroom, 0);

        vm.prank(ADMIN);
        rule.bindToken(CALLER);
        assertEq(rule.detectTransferRestriction(address(0), ALICE, 100), OK);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 1), OK);
        (code, headroom) = rule.remainingMintable();
        assertEq(code, OK);
        assertEq(headroom, 100);

        vm.prank(ADMIN);
        rule.unbindToken(CALLER);
        _assertUnbound(address(rule));
    }

    function testMintAllowanceUnboundThenBound() public {
        RuleMintAllowance rule = new RuleMintAllowance(ADMIN);
        _assertUnbound(address(rule));

        vm.startPrank(ADMIN);
        rule.bindToken(CALLER);
        rule.setMintAllowance(ADMIN, 1);
        vm.stopPrank();
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 1), OK);
        assertTrue(rule.canTransfer(ALICE, BOB, 1));
        assertEq(rule.detectTransferRestrictionFrom(ADMIN, address(0), ALICE, 1), OK);
        assertEq(rule.detectTransferRestrictionFrom(ADMIN, address(0), ALICE, 2), rule.CODE_MINTER_ALLOWANCE_EXCEEDED());
    }

    /// @notice Either binding makes the rule executable: the token (direct) or the RuleEngine (engine topology).
    function testConditionalTransferUnboundThenEngineOnlyThenTokenOnly() public {
        RuleConditionalTransferLight rule = new RuleConditionalTransferLight(ADMIN);
        _assertUnbound(address(rule));

        vm.prank(ADMIN);
        rule.bindRuleEngine(CALLER);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 1), rule.CODE_TRANSFER_REQUEST_NOT_APPROVED());
        assertEq(rule.detectTransferRestriction(address(0), ALICE, 1), OK);

        vm.startPrank(ADMIN);
        rule.unbindRuleEngine();
        rule.bindToken(CALLER);
        vm.stopPrank();
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 1), rule.CODE_TRANSFER_REQUEST_NOT_APPROVED());
        assertEq(rule.detectTransferRestriction(address(0), ALICE, 1), OK);
    }
}

interface IViews {
    function detectTransferRestriction(address from, address to, uint256 value) external view returns (uint8);
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        external
        view
        returns (uint8);
    function canTransfer(address from, address to, uint256 value) external view returns (bool);
    function canTransferFrom(address spender, address from, address to, uint256 value) external view returns (bool);
    function canReturnTransferRestrictionCode(uint8 code) external view returns (bool);
    function messageForTransferRestriction(uint8 code) external view returns (string memory);
}
