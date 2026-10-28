// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {RuleIssuanceCapInvariantStorage} from "src/rules/operation/abstract/RuleIssuanceCapInvariantStorage.sol";
import {TokenBindingModuleInvariantStorage} from "RuleEngine/modules/library/TokenBindingModuleInvariantStorage.sol";

/**
 * @notice Test-only: re-phases the write path to `value = 0`, as the ERC-3643 variants do, to prove the
 * counter is still enforced with the real amount in `_afterMintChecked`.
 */
contract RuleIssuanceCapRePhasedHarness is RuleIssuanceCap {
    constructor(address admin, address token, uint256 cap, uint256 initialIssued)
        RuleIssuanceCap(admin, token, cap, initialIssued)
    {}

    function _detectTransferRestrictionOnNotify(address from, address to, uint256)
        internal
        view
        override
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, 0);
    }
}

/// @notice A token whose `totalSupply()` can be made to revert after the rule was configured.
contract BreakableSupplyToken {
    bool public broken;

    function breakIt() external {
        broken = true;
    }

    function totalSupply() external view returns (uint256) {
        require(!broken, "broken");
        return 0;
    }
}

contract RuleIssuanceCapUnit is Test, HelperContract, RuleIssuanceCapInvariantStorage {
    uint256 private constant CAP = 100;
    /// @dev Plays the token (or RuleEngine) bound to the rule.
    address private constant CALLER = address(0xCA11);

    TotalSupplyMock private token;
    RuleIssuanceCap private rule;

    function setUp() public {
        token = new TotalSupplyMock();
        rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(CALLER);
    }

    /// @dev Mint `value` through the rule and mirror it on the token, as a real token would.
    function _mint(uint256 value) private {
        vm.prank(CALLER);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, value);
        token.setTotalSupply(token.totalSupply() + value);
    }

    function _burn(uint256 value) private {
        vm.prank(CALLER);
        rule.transferred(ADDRESS1, ZERO_ADDRESS, value);
        token.setTotalSupply(token.totalSupply() - value);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testConstructorAnnouncesConfiguration() public {
        token.setTotalSupply(30);
        vm.expectEmit();
        emit MaxTotalSupplyUpdated(0, CAP);
        vm.expectEmit();
        emit TotalIssuedInitialized(50);
        RuleIssuanceCap fresh = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 50);
        assertEq(fresh.totalIssued(), 50);
        assertEq(fresh.maxTotalSupply(), CAP);
        assertEq(address(fresh.tokenContract()), address(token));
    }

    /// @notice Cumulative issuance can never be below the current supply.
    function testConstructorRejectsInitialIssuedBelowSupply() public {
        token.setTotalSupply(30);
        vm.expectRevert(abi.encodeWithSelector(RuleIssuanceCap_InitialIssuedBelowSupply.selector, 29, 30));
        new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 29);
    }

    /// @notice Boundary: issuance exactly equal to the current supply (nothing burned yet) is accepted.
    function testConstructorAcceptsInitialIssuedEqualToSupply() public {
        token.setTotalSupply(30);
        RuleIssuanceCap fresh = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 30);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        fresh.bindToken(CALLER);
        assertEq(fresh.totalIssued(), 30);
        (, uint256 headroom) = fresh.remainingMintable();
        assertEq(headroom, CAP - 30);
    }

    function testCannotBindTheZeroAddress() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindToken(CALLER);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_InvalidTokenAddress.selector);
        rule.bindToken(ZERO_ADDRESS);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         NON-REPLENISHING COUNTER
    //////////////////////////////////////////////////////////////*/

    function testMintIsRecorded() public {
        vm.expectEmit(address(rule));
        emit IssuanceRecorded(30, 30);
        _mint(30);
        assertEq(rule.totalIssued(), 30);
    }

    function testMintOnTheSpenderPathIsRecorded() public {
        vm.prank(CALLER);
        rule.transferred(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 25);
        assertEq(rule.totalIssued(), 25);
    }

    function testMintLandingExactlyOnTheCap() public {
        _mint(CAP);
        assertEq(rule.totalIssued(), CAP);
    }

    /// @notice The defining behaviour: a burn does not give the room back.
    function testBurnDoesNotRestoreTheCap() public {
        _mint(60);
        _burn(40); // supply 20, issued still 60
        assertEq(rule.totalIssued(), 60);

        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 41), CODE_ISSUANCE_CAP_EXCEEDED);
        assertFalse(rule.canTransfer(ZERO_ADDRESS, ADDRESS1, 41));
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMaxTotalSupply_InvalidTransfer.selector,
                address(rule),
                ZERO_ADDRESS,
                ADDRESS1,
                41,
                CODE_ISSUANCE_CAP_EXCEEDED
            )
        );
        vm.prank(CALLER);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 41);

        _mint(40);
        assertEq(rule.totalIssued(), CAP);
    }

    function testRemainingMintableIsTheSmallerRoom() public {
        _mint(60);
        _burn(40); // counter room 40, live room 80
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, TRANSFER_OK);
        assertEq(headroom, 40);
    }

    /// @notice Mints the counter missed (rule detached) raise the supply; the inherited live leg catches them.
    function testLiveLegCatchesUncountedSupply() public {
        _mint(60);
        token.setTotalSupply(95); // 35 minted while detached
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 10), CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
        (, uint256 headroom) = rule.remainingMintable();
        assertEq(headroom, 5);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMaxTotalSupply_InvalidTransfer.selector,
                address(rule),
                ZERO_ADDRESS,
                ADDRESS1,
                10,
                CODE_MAX_TOTAL_SUPPLY_EXCEEDED
            )
        );
        vm.prank(CALLER);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 10);
    }

    function testZeroValueMintIsANoOp() public {
        _mint(10);
        vm.recordLogs();
        vm.prank(CALLER);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 0);
        assertEq(vm.getRecordedLogs().length, 0, "no event");
        assertEq(rule.totalIssued(), 10);
    }

    function testTransfersAreNotRecorded() public {
        _mint(10);
        vm.prank(CALLER);
        rule.transferred(ADDRESS1, ADDRESS2, 10);
        vm.prank(CALLER);
        rule.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 10);
        assertEq(rule.totalIssued(), 10);
    }

    /// @notice On a write path re-phased to `value = 0` (ERC-3643 shape), the counter still holds.
    function testCounterIsEnforcedOnARePhasedWritePath() public {
        token.setTotalSupply(20);
        RuleIssuanceCapRePhasedHarness rephased =
            new RuleIssuanceCapRePhasedHarness(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 60);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rephased.bindToken(CALLER);
        token.setTotalSupply(61); // post-mint supply: the live leg passes with value 0

        vm.expectRevert(
            abi.encodeWithSelector(RuleIssuanceCap_IssuanceCapExceeded.selector, address(rephased), 60, CAP, 41)
        );
        vm.prank(CALLER);
        rephased.transferred(ZERO_ADDRESS, ADDRESS1, 41);

        vm.prank(CALLER);
        rephased.transferred(ZERO_ADDRESS, ADDRESS1, 40);
        assertEq(rephased.totalIssued(), CAP);
    }

    /// @notice An unreadable supply fails closed on both legs' views, without reverting.
    function testUnreadableSupplyIsReportedNotReverted() public {
        BreakableSupplyToken breakable = new BreakableSupplyToken();
        RuleIssuanceCap fresh = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(breakable), CAP, 0);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        fresh.bindToken(CALLER);
        breakable.breakIt();
        (uint8 code, uint256 headroom) = fresh.remainingMintable();
        assertEq(code, CODE_SUPPLY_ORACLE_UNAVAILABLE);
        assertEq(headroom, 0);
        assertEq(fresh.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_SUPPLY_ORACLE_UNAVAILABLE);
    }

    /*//////////////////////////////////////////////////////////////
                          CAP MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Lowering the cap to the issued amount freezes minting; raising it gives room back.
    function testCapChangesApplyToTheCounter() public {
        _mint(60);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(60);
        (, uint256 headroom) = rule.remainingMintable();
        assertEq(headroom, 0);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_ISSUANCE_CAP_EXCEEDED);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.increaseMaxTotalSupply(15);
        (, headroom) = rule.remainingMintable();
        assertEq(headroom, 15);
    }

    function testCapOperatorRole() public {
        bytes32 role = rule.MAX_TOTAL_SUPPLY_ROLE();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.grantRole(role, ADDRESS2);
        vm.prank(ADDRESS2);
        rule.decreaseMaxTotalSupply(10);
        assertEq(rule.maxTotalSupply(), 90);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, ADDRESS1, role)
        );
        vm.prank(ADDRESS1);
        rule.setMaxTotalSupply(1);
    }

    /// @notice The counter describes one token's history, so the observed token is fixed.
    function testTokenContractIsLocked() public {
        TotalSupplyMock other = new TotalSupplyMock();
        vm.expectRevert(RuleIssuanceCap_TokenContractLocked.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenContract(address(other));
    }

    /*//////////////////////////////////////////////////////////////
                              BINDING
    //////////////////////////////////////////////////////////////*/

    function testUnboundCallerCannotNotify() public {
        bytes4 err = TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector;
        vm.expectRevert(err);
        vm.prank(ATTACKER);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
        vm.expectRevert(err);
        vm.prank(ATTACKER);
        rule.transferred(ATTACKER, ZERO_ADDRESS, ADDRESS1, 1);
        vm.expectRevert(err);
        vm.prank(ATTACKER);
        rule.created(ADDRESS1, 1);
        vm.expectRevert(err);
        vm.prank(ATTACKER);
        rule.destroyed(ADDRESS1, 1);
        assertEq(rule.totalIssued(), 0);
    }

    function testCreatedAndDestroyedAreNoOps() public {
        vm.startPrank(CALLER);
        rule.created(ADDRESS1, 50);
        rule.destroyed(ADDRESS1, 50);
        vm.stopPrank();
        assertEq(rule.totalIssued(), 0);
    }

    function testSingleBinding() public {
        vm.expectRevert(RuleIssuanceCap_TokenAlreadyBound.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS2);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindToken(CALLER);
        rule.bindToken(ADDRESS2);
        vm.stopPrank();
        assertEq(rule.getTokenBound(), ADDRESS2);
    }

    function testBindingRequiresTheComplianceManagerRole() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindToken(CALLER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, ADDRESS1, rule.COMPLIANCE_MANAGER_ROLE()
            )
        );
        vm.prank(ADDRESS1);
        rule.bindToken(ADDRESS1);

        bytes32 role = rule.COMPLIANCE_MANAGER_ROLE();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.grantRole(role, ADDRESS2);
        vm.prank(ADDRESS2);
        rule.bindToken(ADDRESS1);
        assertTrue(rule.isTokenBound(ADDRESS1));
    }

    /*//////////////////////////////////////////////////////////////
                          RESTRICTION CODES
    //////////////////////////////////////////////////////////////*/

    function testRestrictionCodes() public view {
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_ISSUANCE_CAP_EXCEEDED));
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_MAX_TOTAL_SUPPLY_EXCEEDED));
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_SUPPLY_ORACLE_UNAVAILABLE));
        assertFalse(rule.canReturnTransferRestrictionCode(CODE_NONEXISTENT));
        assertEq(rule.messageForTransferRestriction(CODE_ISSUANCE_CAP_EXCEEDED), TEXT_ISSUANCE_CAP_EXCEEDED);
        assertEq(rule.messageForTransferRestriction(CODE_MAX_TOTAL_SUPPLY_EXCEEDED), TEXT_MAX_TOTAL_SUPPLY_EXCEEDED);
        assertEq(rule.messageForTransferRestriction(CODE_NONEXISTENT), TEXT_CODE_NOT_FOUND);
        assertEq(rule.CODE_ISSUANCE_CAP_EXCEEDED(), 86);
    }

    /// @notice Burns and transfers are never blocked, even with the cap exhausted.
    function testTransfersAndBurnsPassWhenTheCapIsExhausted() public {
        _mint(CAP);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK);
        _burn(10);
    }
}
