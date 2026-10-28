// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {RuleMaxBalance} from "src/rules/validation/deployment/RuleMaxBalance.sol";
import {
    RuleMaxBalanceInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleMaxBalanceInvariantStorage.sol";
import {
    RuleAddressSetInvariantStorage
} from "src/rules/validation/abstract/RuleAddressSet/invariantStorage/RuleAddressSetInvariantStorage.sol";
import {BalanceOfMock} from "src/mocks/BalanceOfMock.sol";

contract RuleMaxBalanceUnit is Test, RuleMaxBalanceInvariantStorage, RuleAddressSetInvariantStorage {
    address constant ADMIN = address(0xA11CE);
    address constant ALICE = address(0x11);
    address constant BOB = address(0x12);
    address constant CUSTODIAN = address(0x13);
    address constant ATTACKER = address(0xBAD);
    address constant ZERO = address(0);

    uint256 constant CAP = 100;
    uint8 constant OK = 0;

    BalanceOfMock private token;
    RuleMaxBalance private rule;

    function setUp() public {
        token = new BalanceOfMock();
        rule = new RuleMaxBalance(ADMIN, address(token), CAP);
    }

    /*//////////////////////////////////////////////////////////////
                            CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function testConstructorStoresConfiguration() public view {
        assertEq(address(rule.balanceToken()), address(token));
        assertEq(rule.maxBalance(), CAP);
    }

    function testConstructorRejectsZeroToken() public {
        vm.expectRevert(RuleMaxBalance_TokenAddressZeroNotAllowed.selector);
        new RuleMaxBalance(ADMIN, ZERO, CAP);
    }

    function testConstructorRejectsNonContractToken() public {
        vm.expectRevert(abi.encodeWithSelector(RuleMaxBalance_TokenIsNotAContract.selector, ALICE));
        new RuleMaxBalance(ADMIN, ALICE, CAP);
    }

    function testConstructorAnnouncesConfiguration() public {
        vm.expectEmit(true, true, true, true);
        emit MaxBalanceTokenUpdated(address(token));
        vm.expectEmit(true, true, true, true);
        emit MaxBalanceUpdated(CAP);
        new RuleMaxBalance(ADMIN, address(token), CAP);
    }

    function testSetMaxBalance() public {
        vm.prank(ADMIN);
        rule.setMaxBalance(500);
        assertEq(rule.maxBalance(), 500);
    }

    function testSetMaxBalanceRejectsNonManager() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, ATTACKER, MAX_BALANCE_ROLE)
        );
        rule.setMaxBalance(500);
    }

    function testSetBalanceTokenRejectsNonContract() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(RuleMaxBalance_TokenIsNotAContract.selector, ALICE));
        rule.setBalanceToken(ALICE);
    }

    /**
     * @notice A token with code whose `balanceOf` reverts is rejected at configuration time.
     * @dev Covers the `catch` in `_setBalanceToken`. Code alone is not enough: the probe must
     *      actually succeed, otherwise every transfer would later be blocked with code 81 by a
     *      misconfiguration that could have been caught at setup.
     */
    function testConstructorRejectsTokenWhoseBalanceOfReverts() public {
        BalanceOfMock broken = new BalanceOfMock();
        broken.setReverting(true);
        vm.expectRevert(abi.encodeWithSelector(RuleMaxBalance_TokenBalanceUnavailable.selector, address(broken)));
        new RuleMaxBalance(ADMIN, address(broken), CAP);
    }

    function testSetBalanceTokenRejectsTokenWhoseBalanceOfReverts() public {
        BalanceOfMock broken = new BalanceOfMock();
        broken.setReverting(true);
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(RuleMaxBalance_TokenBalanceUnavailable.selector, address(broken)));
        rule.setBalanceToken(address(broken));
    }

    function testSetBalanceTokenSucceedsAndAnnounces() public {
        BalanceOfMock other = new BalanceOfMock();
        vm.expectEmit(true, true, true, true);
        emit MaxBalanceTokenUpdated(address(other));
        vm.prank(ADMIN);
        rule.setBalanceToken(address(other));
        assertEq(address(rule.balanceToken()), address(other));
    }

    /*//////////////////////////////////////////////////////////////
                          THE CAP ITSELF
    //////////////////////////////////////////////////////////////*/

    function testTransferUnderTheCapIsAllowed() public {
        token.setBalance(BOB, 40);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 60), OK);
    }

    function testTransferExactlyToTheCapIsAllowed() public {
        token.setBalance(BOB, 100);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 0), OK);
        token.setBalance(BOB, 99);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 1), OK);
    }

    function testTransferOverTheCapIsRejected() public {
        token.setBalance(BOB, 40);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 61), CODE_MAX_BALANCE_EXCEEDED);
    }

    function testHolderAlreadyOverTheCapCannotReceiveMore() public {
        token.setBalance(BOB, 500);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 1), CODE_MAX_BALANCE_EXCEEDED);
    }

    /// The sender is never screened: reducing a balance cannot breach a maximum.
    function testSenderOverTheCapMayStillSend() public {
        token.setBalance(ALICE, 500);
        token.setBalance(BOB, 0);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 100), OK);
    }

    /// A mint raises the receiver's balance, so it is capped like any transfer.
    function testMintIsCapped() public {
        token.setBalance(BOB, 100);
        assertEq(rule.detectTransferRestriction(ZERO, BOB, 1), CODE_MAX_BALANCE_EXCEEDED);
    }

    /// Burning cannot breach a maximum, and address(0) is a sentinel rather than a holder.
    function testBurnIsExempt() public {
        token.setBalance(ZERO, type(uint256).max);
        assertEq(rule.detectTransferRestriction(ALICE, ZERO, type(uint256).max), OK);
    }

    /// No magic zero: a cap of 0 forbids holding, it does not disable the rule.
    function testZeroCapForbidsHolding() public {
        vm.prank(ADMIN);
        rule.setMaxBalance(0);
        token.setBalance(BOB, 0);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 1), CODE_MAX_BALANCE_EXCEEDED);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 0), OK);
    }

    /// `balance + value` must not overflow the MUST-NOT-revert view.
    function testNoOverflowNearMaxUint() public {
        vm.prank(ADMIN);
        rule.setMaxBalance(type(uint256).max);
        token.setBalance(BOB, type(uint256).max - 1);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 1), OK);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 2), CODE_MAX_BALANCE_EXCEEDED);
    }

    /*//////////////////////////////////////////////////////////////
                            EXEMPTIONS
    //////////////////////////////////////////////////////////////*/

    function testExemptAddressMayHoldAnyAmount() public {
        token.setBalance(CUSTODIAN, type(uint256).max - 1);
        assertEq(rule.detectTransferRestriction(ALICE, CUSTODIAN, 1), CODE_MAX_BALANCE_EXCEEDED);

        vm.prank(ADMIN);
        rule.addExemptAddress(CUSTODIAN);

        assertTrue(rule.isExemptAddress(CUSTODIAN));
        assertEq(rule.detectTransferRestriction(ALICE, CUSTODIAN, 1), OK);
    }

    function testAddExemptAddressEmits() public {
        vm.expectEmit(true, true, true, true);
        emit ExemptAddressAdded(CUSTODIAN);
        vm.prank(ADMIN);
        rule.addExemptAddress(CUSTODIAN);
        assertEq(rule.exemptAddressCount(), 1);
    }

    function testRemoveExemptAddressRestoresTheCap() public {
        vm.startPrank(ADMIN);
        rule.addExemptAddress(CUSTODIAN);
        vm.expectEmit(true, true, true, true);
        emit ExemptAddressRemoved(CUSTODIAN);
        rule.removeExemptAddress(CUSTODIAN);
        vm.stopPrank();

        assertFalse(rule.isExemptAddress(CUSTODIAN));
        token.setBalance(CUSTODIAN, CAP);
        assertEq(rule.detectTransferRestriction(ALICE, CUSTODIAN, 1), CODE_MAX_BALANCE_EXCEEDED);
    }

    function testAddExemptAddressRejectsDuplicate() public {
        vm.startPrank(ADMIN);
        rule.addExemptAddress(CUSTODIAN);
        vm.expectRevert(RuleAddressSet_AddressAlreadyListed.selector);
        rule.addExemptAddress(CUSTODIAN);
        vm.stopPrank();
    }

    function testRemoveExemptAddressRejectsUnknown() public {
        vm.prank(ADMIN);
        vm.expectRevert(RuleAddressSet_AddressNotFound.selector);
        rule.removeExemptAddress(CUSTODIAN);
    }

    function testAddExemptAddressRejectsZeroAddress() public {
        vm.prank(ADMIN);
        vm.expectRevert(RuleAddressSet_ZeroAddressNotAllowed.selector);
        rule.addExemptAddress(ZERO);
    }

    /// The batch path is guarded by the shared library's function pointer; the whole batch reverts.
    function testBatchExemptionRejectsZeroAddressAndAppliesNothing() public {
        address[] memory batch = new address[](2);
        batch[0] = CUSTODIAN;
        batch[1] = ZERO;

        vm.prank(ADMIN);
        vm.expectRevert(RuleAddressSet_ZeroAddressNotAllowed.selector);
        rule.addExemptAddresses(batch);

        assertEq(rule.exemptAddressCount(), 0, "a rejected batch must apply nothing");
        assertFalse(rule.isExemptAddress(CUSTODIAN));
    }

    function testExemptionRejectsNonManager() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, ATTACKER, MAX_BALANCE_ROLE)
        );
        rule.addExemptAddress(CUSTODIAN);
    }

    function testBatchExemptionReportsCounters() public {
        address[] memory batch = new address[](2);
        batch[0] = CUSTODIAN;
        batch[1] = BOB;

        vm.startPrank(ADMIN);
        rule.addExemptAddresses(batch);
        assertEq(rule.exemptAddressCount(), 2);

        // A second identical batch is entirely redundant: 0 added, 2 skipped.
        vm.expectEmit(true, true, true, true);
        emit ExemptAddressesAdded(batch, 0, 2);
        rule.addExemptAddresses(batch);

        vm.expectEmit(true, true, true, true);
        emit ExemptAddressesRemoved(batch, 2, 0);
        rule.removeExemptAddresses(batch);
        vm.stopPrank();

        assertEq(rule.exemptAddressCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    REVERT-FREE READ PATH
    //////////////////////////////////////////////////////////////*/

    /// A token that breaks after configuration must yield a code, never revert the view.
    function testBrokenTokenYieldsCodeInsteadOfReverting() public {
        token.setReverting(true);
        assertEq(rule.detectTransferRestriction(ALICE, BOB, 1), CODE_BALANCE_UNAVAILABLE);
        assertFalse(rule.canTransfer(ALICE, BOB, 1));
    }

    function testBrokenTokenStillAllowsBurnAndExempt() public {
        vm.prank(ADMIN);
        rule.addExemptAddress(CUSTODIAN);
        token.setReverting(true);
        // Neither branch reads a balance, so neither is affected.
        assertEq(rule.detectTransferRestriction(ALICE, ZERO, 1), OK);
        assertEq(rule.detectTransferRestriction(ALICE, CUSTODIAN, 1), OK);
    }

    /*//////////////////////////////////////////////////////////////
                        WRITE PATH AND VIEWS
    //////////////////////////////////////////////////////////////*/

    function testTransferredRevertsWhenOverTheCap() public {
        token.setBalance(BOB, CAP);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMaxBalance_InvalidTransfer.selector, address(rule), ALICE, BOB, 1, CODE_MAX_BALANCE_EXCEEDED
            )
        );
        rule.transferred(ALICE, BOB, 1);
    }

    function testTransferredFromRevertsWhenOverTheCap() public {
        token.setBalance(BOB, CAP);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMaxBalance_InvalidTransferFrom.selector,
                address(rule),
                ATTACKER,
                ALICE,
                BOB,
                1,
                CODE_MAX_BALANCE_EXCEEDED
            )
        );
        rule.transferred(ATTACKER, ALICE, BOB, 1);
    }

    /// The spender is irrelevant: the cap constrains who ends up holding the tokens.
    function testSpenderDoesNotAffectTheOutcome() public {
        token.setBalance(BOB, 40);
        assertEq(rule.detectTransferRestrictionFrom(ATTACKER, ALICE, BOB, 60), OK);
        assertEq(rule.detectTransferRestrictionFrom(CUSTODIAN, ALICE, BOB, 61), CODE_MAX_BALANCE_EXCEEDED);
    }

    function testRemainingCapacity() public {
        token.setBalance(BOB, 40);
        (uint8 code, uint256 headroom) = rule.remainingCapacity(BOB);
        assertEq(code, OK);
        assertEq(headroom, 60);

        token.setBalance(BOB, 500);
        (, headroom) = rule.remainingCapacity(BOB);
        assertEq(headroom, 0);

        vm.prank(ADMIN);
        rule.addExemptAddress(BOB);
        (, headroom) = rule.remainingCapacity(BOB);
        assertEq(headroom, type(uint256).max);
    }

    function testRemainingCapacityReportsBrokenToken() public {
        token.setReverting(true);
        (uint8 code,) = rule.remainingCapacity(BOB);
        assertEq(code, CODE_BALANCE_UNAVAILABLE);
    }

    function testMessagesAndCodes() public view {
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_MAX_BALANCE_EXCEEDED));
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_BALANCE_UNAVAILABLE));
        assertFalse(rule.canReturnTransferRestrictionCode(1));
        assertEq(rule.messageForTransferRestriction(CODE_MAX_BALANCE_EXCEEDED), TEXT_MAX_BALANCE_EXCEEDED);
        assertEq(rule.messageForTransferRestriction(CODE_BALANCE_UNAVAILABLE), TEXT_BALANCE_UNAVAILABLE);
        assertEq(rule.messageForTransferRestriction(1), TEXT_CODE_NOT_FOUND);
    }

    /*//////////////////////////////////////////////////////////////
                        THE DOCUMENTED BYPASS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pins the limitation the documentation warns about: the cap is per **address**, so one
     *         holder with two addresses can hold 2x the cap without the rule objecting.
     * @dev This asserts behaviour that is correct-as-designed but exploitable in isolation. It is
     *      why `doc/technical/contracts/RuleMaxBalance.md` requires pairing the rule with a one-address-per-
     *      investor rule. If a future change makes this fail, the mitigation is no longer needed and
     *      the documentation must be updated with it.
     */
    function testCapIsPerAddressSoSplittingBypassesIt() public {
        address walletA = address(0x21);
        address walletB = address(0x22);

        token.setBalance(walletA, CAP);
        token.setBalance(walletB, 0);

        // walletA is full...
        assertEq(rule.detectTransferRestriction(ALICE, walletA, 1), CODE_MAX_BALANCE_EXCEEDED);
        // ...but the same person's second wallet accepts another full cap.
        assertEq(rule.detectTransferRestriction(ALICE, walletB, CAP), OK);
    }
}
