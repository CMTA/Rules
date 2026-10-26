// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RuleMaxTotalSupplyUnit is Test, HelperContract {
    TotalSupplyMock private token;
    RuleMaxTotalSupply private rule;

    function setUp() public {
        token = new TotalSupplyMock();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), 100);
    }

    function testConstructor_RevertsOnZeroToken() public {
        vm.expectRevert(RuleMaxTotalSupply_TokenAddressZeroNotAllowed.selector);
        new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, 100);
    }

    /*//////////////////////////////////////////////////////////////
                  TOKEN CONTRACT VALIDITY (F-2 REGRESSION)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice A non-contract token is rejected by an explicit check, not by the compiler's
     *         uncatchable extcodesize revert that the `totalSupply()` probe would produce.
     */
    function testConstructor_RevertsOnNonContractToken() public {
        vm.expectRevert(abi.encodeWithSelector(RuleMaxTotalSupply_TokenIsNotAContract.selector, ADDRESS1));
        new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, ADDRESS1, 100);
    }

    function testSetTokenContract_RevertsOnNonContract() public {
        vm.expectRevert(abi.encodeWithSelector(RuleMaxTotalSupply_TokenIsNotAContract.selector, ADDRESS1));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenContract(ADDRESS1);
    }

    /**
     * @notice `totalSupply()` is mandatory: a contract without it is rejected at configuration
     *         rather than silently bricking the read path later.
     */
    function testConstructor_RevertsWhenTotalSupplyMissing() public {
        NoTotalSupplyMock noSupply = new NoTotalSupplyMock();
        vm.expectRevert(
            abi.encodeWithSelector(RuleMaxTotalSupply_TokenTotalSupplyUnavailable.selector, address(noSupply))
        );
        new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(noSupply), 100);
    }

    function testSetTokenContract_RevertsWhenTotalSupplyMissing() public {
        NoTotalSupplyMock noSupply = new NoTotalSupplyMock();
        vm.expectRevert(
            abi.encodeWithSelector(RuleMaxTotalSupply_TokenTotalSupplyUnavailable.selector, address(noSupply))
        );
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenContract(address(noSupply));
    }

    /**
     * @notice If the token breaks AFTER configuration the read path must still return a code:
     *         the ERC-1404 / ERC-3643 views MUST NOT revert.
     */
    function testRevertingTotalSupplyYieldsACodeNotARevert() public {
        RevertingTotalSupplyMock breakable = new RevertingTotalSupplyMock();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenContract(address(breakable));
        breakable.setRevertOnTotalSupply(true);

        assertEq(
            rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_SUPPLY_ORACLE_UNAVAILABLE, "must not revert"
        );
        assertFalse(rule.canTransfer(ZERO_ADDRESS, ADDRESS1, 1));
        assertEq(
            rule.detectTransferRestrictionFrom(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 1), CODE_SUPPLY_ORACLE_UNAVAILABLE
        );

        // Transfers and burns never read the supply, so they are unaffected.
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 1), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 1), TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                          remainingMintable
    //////////////////////////////////////////////////////////////*/

    function testRemainingMintableIsCapMinusSupply() public {
        token.setTotalSupply(60);
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, TRANSFER_OK);
        assertEq(headroom, 40);
    }

    function testRemainingMintableIsZeroAtTheCap() public {
        token.setTotalSupply(100);
        (, uint256 headroom) = rule.remainingMintable();
        assertEq(headroom, 0);
    }

    /// @notice A cap lowered below the supply saturates at 0 instead of underflowing.
    function testRemainingMintableSaturatesWhenTheCapIsBelowTheSupply() public {
        token.setTotalSupply(60);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(10);
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, TRANSFER_OK);
        assertEq(headroom, 0);
    }

    function testRemainingMintableReportsAnUnreadableSupply() public {
        RevertingTotalSupplyMock breakable = new RevertingTotalSupplyMock();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenContract(address(breakable));
        breakable.setRevertOnTotalSupply(true);
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, CODE_SUPPLY_ORACLE_UNAVAILABLE);
        assertEq(headroom, 0);
    }

    /// @notice The headroom is exactly the largest mint the pre-flight check accepts.
    function testFuzz_RemainingMintableAgreesWithTheMintCheck(uint256 supply, uint256 cap) public {
        token.setTotalSupply(supply);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(cap);
        (, uint256 headroom) = rule.remainingMintable();
        if (supply > cap) {
            // Already over the line: no headroom, and even a zero mint is rejected.
            assertEq(headroom, 0);
            assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 0), CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
            return;
        }
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, headroom), TRANSFER_OK);
        if (headroom != type(uint256).max) {
            assertEq(
                rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, headroom + 1), CODE_MAX_TOTAL_SUPPLY_EXCEEDED
            );
        }
    }

    function testTransferred_RevertsWithTheSupplyOracleCode() public {
        RevertingTotalSupplyMock breakable = new RevertingTotalSupplyMock();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenContract(address(breakable));
        breakable.setRevertOnTotalSupply(true);

        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMaxTotalSupply_InvalidTransfer.selector,
                address(rule),
                ZERO_ADDRESS,
                ADDRESS1,
                1,
                CODE_SUPPLY_ORACLE_UNAVAILABLE
            )
        );
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testSetTokenContract_RevertsOnZero() public {
        vm.expectRevert(RuleMaxTotalSupply_TokenAddressZeroNotAllowed.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenContract(ZERO_ADDRESS);
    }

    function testSetTokenContract_OnlyAdmin() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.setTokenContract(address(token));
    }

    /*//////////////////////////////////////////////////////////////
                         MAX_TOTAL_SUPPLY_ROLE
    //////////////////////////////////////////////////////////////*/

    function testMaxTotalSupplyRoleHash() public view {
        assertEq(rule.MAX_TOTAL_SUPPLY_ROLE(), keccak256("MAX_TOTAL_SUPPLY_ROLE"));
    }

    function testCapOperatorCanSetTheCapButNotTheToken() public {
        bytes32 role = rule.MAX_TOTAL_SUPPLY_ROLE();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.grantRole(role, ADDRESS2);

        vm.prank(ADDRESS2);
        rule.setMaxTotalSupply(200);
        assertEq(rule.maxTotalSupply(), 200);

        TotalSupplyMock other = new TotalSupplyMock();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, ADDRESS2, bytes32(0))
        );
        vm.prank(ADDRESS2);
        rule.setTokenContract(address(other));
    }

    function testSetMaxTotalSupplyRequiresTheRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, ADDRESS1, rule.MAX_TOTAL_SUPPLY_ROLE()
            )
        );
        vm.prank(ADDRESS1);
        rule.setMaxTotalSupply(200);
    }

    function testRevokedCapOperatorLosesAccess() public {
        bytes32 role = rule.MAX_TOTAL_SUPPLY_ROLE();
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.grantRole(role, ADDRESS2);
        rule.revokeRole(role, ADDRESS2);
        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, ADDRESS2, role)
        );
        vm.prank(ADDRESS2);
        rule.setMaxTotalSupply(200);
    }

    /// @notice Existing deployments are unaffected: the admin holds the new role implicitly.
    function testAdminHoldsTheRoleImplicitly() public {
        assertTrue(rule.hasRole(rule.MAX_TOTAL_SUPPLY_ROLE(), DEFAULT_ADMIN_ADDRESS));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(300);
        assertEq(rule.maxTotalSupply(), 300);
    }

    /// @notice Each update reports the cap it replaces, so one event is self-describing.
    function testSetMaxTotalSupplyEmitsPreviousAndNewCap() public {
        vm.expectEmit(address(rule));
        emit MaxTotalSupplyUpdated(100, 250);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(250);

        vm.expectEmit(address(rule));
        emit MaxTotalSupplyUpdated(250, 0);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(0);
    }

    /*//////////////////////////////////////////////////////////////
                   increase / decreaseMaxTotalSupply
    //////////////////////////////////////////////////////////////*/

    function testIncreaseMaxTotalSupply() public {
        vm.expectEmit(address(rule));
        emit MaxTotalSupplyUpdated(100, 150);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.increaseMaxTotalSupply(50);
        assertEq(rule.maxTotalSupply(), 150);
    }

    function testDecreaseMaxTotalSupply() public {
        vm.expectEmit(address(rule));
        emit MaxTotalSupplyUpdated(100, 30);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.decreaseMaxTotalSupply(70);
        assertEq(rule.maxTotalSupply(), 30);
    }

    function testDecreaseToExactlyZero() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.decreaseMaxTotalSupply(100);
        assertEq(rule.maxTotalSupply(), 0);
    }

    function testCannotDecreaseBelowZero() public {
        vm.expectRevert(abi.encodeWithSelector(RuleMaxTotalSupply_DecreaseBelowZero.selector, 100, 101));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.decreaseMaxTotalSupply(101);
    }

    function testCannotIncreasePastUint256Max() public {
        uint256 amount = type(uint256).max - 99;
        vm.expectRevert(abi.encodeWithSelector(RuleMaxTotalSupply_IncreaseOverflow.selector, 100, amount));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.increaseMaxTotalSupply(amount);
    }

    function testIncreaseUpToUint256Max() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.increaseMaxTotalSupply(type(uint256).max - 100);
        assertEq(rule.maxTotalSupply(), type(uint256).max);
    }

    /// @notice Two increases approved against the same old cap compose; two absolute sets would not.
    function testTwoIncreasesCompose() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.increaseMaxTotalSupply(25);
        rule.increaseMaxTotalSupply(25);
        vm.stopPrank();
        assertEq(rule.maxTotalSupply(), 150);
    }

    /// @notice Lowering the cap below the supply is allowed: it freezes minting, nothing else.
    function testDecreaseBelowSupplyFreezesMinting() public {
        token.setTotalSupply(80);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.decreaseMaxTotalSupply(50);
        (, uint256 headroom) = rule.remainingMintable();
        assertEq(headroom, 0);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
    }

    function testCapOperatorCanIncreaseAndDecrease() public {
        bytes32 role = rule.MAX_TOTAL_SUPPLY_ROLE();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.grantRole(role, ADDRESS2);
        vm.startPrank(ADDRESS2);
        rule.increaseMaxTotalSupply(10);
        rule.decreaseMaxTotalSupply(20);
        vm.stopPrank();
        assertEq(rule.maxTotalSupply(), 90);
    }

    function testIncreaseAndDecreaseRequireTheRole() public {
        bytes memory err = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, ADDRESS1, rule.MAX_TOTAL_SUPPLY_ROLE()
        );
        vm.expectRevert(err);
        vm.prank(ADDRESS1);
        rule.increaseMaxTotalSupply(1);
        vm.expectRevert(err);
        vm.prank(ADDRESS1);
        rule.decreaseMaxTotalSupply(1);
    }

    function testSetMaxTotalSupply_OnlyAdmin() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.setMaxTotalSupply(200);
    }

    function testDetectRestriction_MintExceedsMaxSupply() public {
        token.setTotalSupply(90);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 11);
        assertEq(resUint8, CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
    }

    function testDetectRestriction_MintWithinMaxSupply() public {
        token.setTotalSupply(90);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 10);
        assertEq(resUint8, TRANSFER_OK);
    }

    function testDetectRestriction_NonMintTransfer() public {
        token.setTotalSupply(100);
        resUint8 = rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 50);
        assertEq(resUint8, TRANSFER_OK);
    }

    function testTransferred_RevertsOnInvalidTransfer() public {
        token.setTotalSupply(100);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMaxTotalSupply_InvalidTransfer.selector,
                address(rule),
                ZERO_ADDRESS,
                ADDRESS1,
                1,
                CODE_MAX_TOTAL_SUPPLY_EXCEEDED
            )
        );
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testTransferredFrom_RevertsOnInvalidTransfer() public {
        token.setTotalSupply(100);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMaxTotalSupply_InvalidTransferFrom.selector,
                address(rule),
                ADDRESS3,
                ZERO_ADDRESS,
                ADDRESS1,
                1,
                CODE_MAX_TOTAL_SUPPLY_EXCEEDED
            )
        );
        rule.transferred(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testTransferred_DoesNotRevertWhenValid() public {
        token.setTotalSupply(90);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 10);
    }

    function testTransferredFrom_DoesNotRevertWhenValid() public {
        token.setTotalSupply(90);
        rule.transferred(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 10);
    }

    function testCanReturnTransferRestrictionCode() public view {
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_MAX_TOTAL_SUPPLY_EXCEEDED));
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_SUPPLY_ORACLE_UNAVAILABLE));
        assertFalse(rule.canReturnTransferRestrictionCode(CODE_NONEXISTENT));
    }

    function testMessageForTransferRestriction() public view {
        assertEq(rule.messageForTransferRestriction(CODE_MAX_TOTAL_SUPPLY_EXCEEDED), TEXT_MAX_TOTAL_SUPPLY_EXCEEDED);
        assertEq(rule.messageForTransferRestriction(CODE_SUPPLY_ORACLE_UNAVAILABLE), TEXT_SUPPLY_ORACLE_UNAVAILABLE);
        assertEq(rule.messageForTransferRestriction(CODE_NONEXISTENT), TEXT_CODE_NOT_FOUND);
    }
}

/**
 * @notice Has code but no `totalSupply()`: the shape that previously passed configuration and then
 *         reverted the read path.
 */
contract NoTotalSupplyMock {
    // Intentionally empty: it has code, but no `totalSupply()` to call.

    }

/**
 * @notice A token whose `totalSupply()` can be made to revert after configuration.
 */
contract RevertingTotalSupplyMock {
    bool private _shouldRevert;

    function setRevertOnTotalSupply(bool shouldRevert) external {
        _shouldRevert = shouldRevert;
    }

    function totalSupply() external view returns (uint256) {
        require(!_shouldRevert, RevertingTotalSupplyMock_Unavailable());
        return 0;
    }

    error RevertingTotalSupplyMock_Unavailable();
}
