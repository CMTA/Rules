// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {TokenBindingModuleInvariantStorage} from "RuleEngine/modules/library/TokenBindingModuleInvariantStorage.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {RuleIssuanceCapInvariantStorage} from "src/rules/operation/abstract/RuleIssuanceCapInvariantStorage.sol";

/**
 * @notice Test-only: a naive subclass that records mints in `_afterMintChecked` but forgets to gate
 * `transferred`, which `RuleMaxTotalSupplyBase` leaves public and unrestricted.
 */
contract UngatedMintRecorder is RuleMaxTotalSupply {
    uint256 public recorded;

    constructor(address admin, address token, uint256 cap) RuleMaxTotalSupply(admin, token, cap) {}

    function _afterMintChecked(uint256 value) internal override {
        recorded += value;
    }
}

/**
 * @title ThreatModelV070Tests
 * @notice Proof-of-concept tests for the v0.7.0 audit (`CLAUDE_AUDIT.md`, v0.7.0). Scope: the
 * code added or changed since v0.6.0 (`RuleIssuanceCap`, `RuleMaxTotalSupply` setters and hook, code 85).
 * @dev Each test names the threat ID it exercises. Tests suffixed `_CurrentBehaviour` assert behaviour the
 * audit considers a hazard; a fix must make them fail.
 */
contract ThreatModelV070Tests is Test, HelperContract, RuleIssuanceCapInvariantStorage {
    uint256 private constant CAP = 100;

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _newToken() private returns (CMTATStandardStandalone) {
        return new CMTATDeployment().cmtat();
    }

    /// @dev A RuleEngine serving two tokens, with one RuleIssuanceCap observing `tokenA`.
    function _sharedEngine()
        private
        returns (CMTATStandardStandalone tokenA, CMTATStandardStandalone tokenB, RuleIssuanceCap rule)
    {
        tokenA = _newToken();
        tokenB = _newToken();
        rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(tokenA), CAP, 0);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(tokenA));
        engine.bindToken(address(tokenB));
        engine.addRule(rule);
        rule.bindToken(address(engine));
        tokenA.setRuleEngine(IRuleEngine(address(engine)));
        tokenB.setRuleEngine(IRuleEngine(address(engine)));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
        IC-1  Engine bound to several tokens shares one counter
    //////////////////////////////////////////////////////////////*/

    /// @notice IC-1: token B's mints are recorded in the counter of token A's issuance cap.
    function testIC1_SharedEngineCountsOtherTokensMints_CurrentBehaviour() public {
        (CMTATStandardStandalone tokenA, CMTATStandardStandalone tokenB, RuleIssuanceCap rule) = _sharedEngine();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenB.mint(ADDRESS1, 90);

        assertEq(tokenA.totalSupply(), 0);
        assertEq(rule.totalIssued(), 90, "token B's mint consumed token A's budget");

        // Token A has issued nothing, yet can mint only 10.
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransferFrom.selector);
        tokenA.mint(ADDRESS1, 11);
        tokenA.mint(ADDRESS1, 10);
        vm.stopPrank();
    }

    /// @notice IC-1: token B is capped only by the counter, never by its own supply, which the rule does not read.
    function testIC1_SharedEngineCapsTokenBByTokenAsCounter_CurrentBehaviour() public {
        (CMTATStandardStandalone tokenA, CMTATStandardStandalone tokenB, RuleIssuanceCap rule) = _sharedEngine();
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        tokenA.mint(ADDRESS1, 100);
        // Token B has never minted, and is blocked by token A's history.
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransferFrom.selector);
        tokenB.mint(ADDRESS1, 1);
        vm.stopPrank();
        assertEq(rule.totalIssued(), 100);
        assertEq(tokenB.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
        IC-2  The bound caller is not checked against tokenContract
    //////////////////////////////////////////////////////////////*/

    /// @notice IC-2: binding an address unrelated to `tokenContract` is accepted; the real token's mints then revert.
    function testIC2_BindingUnrelatedCallerIsAccepted_CurrentBehaviour() public {
        CMTATStandardStandalone token = _newToken();
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(0xBEEF)); // not the token, not an engine serving it
        token.setRuleEngine(IRuleEngine(address(rule)));
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);
        vm.stopPrank();
        // The read path does not see the misbinding: it reports OK.
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
        IC-3  Mints before binding / while detached are not counted
    //////////////////////////////////////////////////////////////*/

    /// @notice IC-3: mint-and-burn before the rule is attached is invisible to the counter.
    function testIC3_IssuanceBeforeAttachIsNotCounted_CurrentBehaviour() public {
        CMTATStandardStandalone token = _newToken();
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        // Between deployment and attachment: a full cap issued, then redeemed.
        token.mint(ADDRESS1, CAP);
        token.burn(ADDRESS1, CAP);
        rule.bindToken(address(token));
        token.setRuleEngine(IRuleEngine(address(rule)));
        token.mint(ADDRESS1, CAP);
        vm.stopPrank();
        // Cumulative issuance is 2 * CAP; the counter records CAP.
        assertEq(rule.totalIssued(), CAP);
    }

    /// @notice IC-3 control: the live-supply leg still holds the supply under the cap after a detached mint.
    function testIC3_LiveLegCatchesDetachedOverMint() public {
        CMTATStandardStandalone token = _newToken();
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));
        token.setRuleEngine(IRuleEngine(address(rule)));
        token.mint(ADDRESS1, 10);
        token.setRuleEngine(IRuleEngine(address(0)));
        token.mint(ADDRESS1, CAP); // supply 110, counter 10
        token.setRuleEngine(IRuleEngine(address(rule)));
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransferFrom.selector);
        token.mint(ADDRESS1, 1);
        vm.stopPrank();
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
    }

    /*//////////////////////////////////////////////////////////////
        IC-4  Only the bound caller can record a mint
    //////////////////////////////////////////////////////////////*/

    /// @notice IC-4: no other caller, including the admin, can move the counter through either overload.
    function testFuzz_IC4_OnlyBoundCallerRecords(address caller, address spender, uint256 value) public {
        TotalSupplyMock token = new TotalSupplyMock();
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        address boundCaller = address(0xCA11);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(boundCaller);
        vm.assume(caller != boundCaller);
        value = bound(value, 0, CAP);

        vm.prank(caller);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, value);
        vm.prank(caller);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        rule.transferred(spender, ZERO_ADDRESS, ADDRESS1, value);
        vm.prank(caller);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        rule.created(ADDRESS1, value);
        assertEq(rule.totalIssued(), 0);
    }

    /// @notice IC-4: a second binding is refused; re-binding after unbind keeps the counter.
    function testIC4_SingleBindingAndCounterSurvivesRebind() public {
        TotalSupplyMock token = new TotalSupplyMock();
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(0xA));
        vm.expectRevert(RuleIssuanceCap_TokenAlreadyBound.selector);
        rule.bindToken(address(0xB));
        vm.stopPrank();

        vm.prank(address(0xA));
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 40);
        token.setTotalSupply(40);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindToken(address(0xA));
        rule.bindToken(address(0xB));
        vm.stopPrank();
        assertEq(rule.totalIssued(), 40);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 61), CODE_ISSUANCE_CAP_EXCEEDED);
    }

    /// @notice IC-4: the observed token is locked, even for the admin.
    function testIC4_TokenContractLockedForAdmin() public {
        TotalSupplyMock token = new TotalSupplyMock();
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        TotalSupplyMock other = new TotalSupplyMock();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleIssuanceCap_TokenContractLocked.selector);
        rule.setTokenContract(address(other));
    }

    /*//////////////////////////////////////////////////////////////
        IC-5  Read path and write path agree
    //////////////////////////////////////////////////////////////*/

    /// @notice IC-5: for any counter, supply, cap and amount, the view reports OK iff the bound mint succeeds.
    function testFuzz_IC5_ViewMatchesEnforcement(uint256 issued, uint256 supply, uint256 cap, uint256 value) public {
        cap = bound(cap, 0, type(uint128).max);
        issued = bound(issued, 0, type(uint128).max);
        supply = bound(supply, 0, issued);
        value = bound(value, 0, type(uint128).max);

        TotalSupplyMock token = new TotalSupplyMock();
        token.setTotalSupply(supply);
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), cap, issued);
        address bound_ = address(0xCA11);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(bound_);

        uint8 code = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, value);
        uint8 codeFrom = rule.detectTransferRestrictionFrom(ADDRESS2, ZERO_ADDRESS, ADDRESS1, value);
        assertEq(code, codeFrom);

        vm.prank(bound_);
        (bool ok,) = address(rule)
            .call(abi.encodeWithSignature("transferred(address,address,uint256)", ZERO_ADDRESS, ADDRESS1, value));
        assertEq(ok, code == TRANSFER_OK, "view and enforcement disagree");
        assertEq(rule.totalIssued(), ok ? issued + value : issued);
    }

    /// @notice IC-5: once the cap is lowered below the counter, even a zero-value mint is refused on both paths.
    function testIC5_ZeroValueMintRefusedAboveCap() public {
        TotalSupplyMock token = new TotalSupplyMock();
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 50);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(0xCA11));
        rule.setMaxTotalSupply(40);
        vm.stopPrank();
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 0), CODE_ISSUANCE_CAP_EXCEEDED);
        vm.prank(address(0xCA11));
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 0);
        // Transfers and burns are not affected.
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 1), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 1), TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
        MTS-1  The ungated write path of RuleMaxTotalSupplyBase
    //////////////////////////////////////////////////////////////*/

    /// @notice MTS-1: the stock rule's `transferred` is callable by anyone, harmlessly, because it writes nothing.
    function testMTS1_StockTransferredIsPublicAndStateless() public {
        TotalSupplyMock token = new TotalSupplyMock();
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
        vm.record();
        vm.prank(ATTACKER);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, CAP);
        (, bytes32[] memory writes) = vm.accesses(address(rule));
        assertEq(writes.length, 0);
    }

    /// @notice MTS-1: a subclass using the `_afterMintChecked` hook without gating `transferred` can be driven
    /// by anyone. `RuleIssuanceCap` gates both overloads; the hook's NatSpec does not warn about this.
    function testMTS1_UngatedSubclassIsDrivableByAnyone_CurrentBehaviour() public {
        TotalSupplyMock token = new TotalSupplyMock();
        UngatedMintRecorder rule = new UngatedMintRecorder(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
        vm.prank(ATTACKER);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, CAP);
        vm.prank(ATTACKER);
        rule.transferred(ATTACKER, ZERO_ADDRESS, ADDRESS1, CAP);
        assertEq(rule.recorded(), 2 * CAP, "a stranger recorded mints that never happened");
    }

    /*//////////////////////////////////////////////////////////////
        MTS-2  Cap setters: role separation and arithmetic
    //////////////////////////////////////////////////////////////*/

    /// @notice MTS-2: MAX_TOTAL_SUPPLY_ROLE changes the cap but cannot repoint the observed token.
    function testMTS2_CapRoleCannotRepointToken() public {
        TotalSupplyMock token = new TotalSupplyMock();
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
        address capManager = address(0xCAB);
        bytes32 capRole = rule.MAX_TOTAL_SUPPLY_ROLE();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.grantRole(capRole, capManager);

        vm.startPrank(capManager);
        rule.increaseMaxTotalSupply(1);
        TotalSupplyMock other = new TotalSupplyMock();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, capManager, rule.DEFAULT_ADMIN_ROLE()
            )
        );
        rule.setTokenContract(address(other));
        vm.stopPrank();
        assertEq(rule.maxTotalSupply(), CAP + 1);
    }

    /// @notice MTS-2: increase / decrease never wrap; out-of-range amounts revert with the named errors.
    function testFuzz_MTS2_IncreaseDecreaseNeverWrap(uint256 start, uint256 amount, bool up) public {
        TotalSupplyMock token = new TotalSupplyMock();
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), start);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        if (up) {
            if (amount > type(uint256).max - start) {
                vm.expectRevert(abi.encodeWithSelector(RuleMaxTotalSupply_IncreaseOverflow.selector, start, amount));
                rule.increaseMaxTotalSupply(amount);
                assertEq(rule.maxTotalSupply(), start);
            } else {
                rule.increaseMaxTotalSupply(amount);
                assertEq(rule.maxTotalSupply(), start + amount);
            }
        } else {
            if (amount > start) {
                vm.expectRevert(abi.encodeWithSelector(RuleMaxTotalSupply_DecreaseBelowZero.selector, start, amount));
                rule.decreaseMaxTotalSupply(amount);
                assertEq(rule.maxTotalSupply(), start);
            } else {
                rule.decreaseMaxTotalSupply(amount);
                assertEq(rule.maxTotalSupply(), start - amount);
            }
        }
        vm.stopPrank();
    }

    /// @notice MTS-2 / IC-6: the cap role can raise an issuance cap at will; non-replenishment is relative to it.
    function testIC6_CapRoleCanRaiseIssuanceCap() public {
        CMTATStandardStandalone token = _newToken();
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));
        token.setRuleEngine(IRuleEngine(address(rule)));
        token.mint(ADDRESS1, CAP);
        token.burn(ADDRESS1, CAP);
        rule.increaseMaxTotalSupply(CAP);
        token.mint(ADDRESS1, CAP);
        vm.stopPrank();
        assertEq(rule.totalIssued(), 2 * CAP);
    }

    /*//////////////////////////////////////////////////////////////
        B85-1  Code 85 is shared by three rules
    //////////////////////////////////////////////////////////////*/

    /// @notice B85-1: behind a RuleEngine, an unbound rule surfaces as 85 with no indication of which rule.
    function testB85_EngineSurfacesSharedCode() public {
        CMTATStandardStandalone token = _newToken();
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(token));
        engine.addRule(rule);
        token.setRuleEngine(IRuleEngine(address(engine)));
        vm.stopPrank();

        // Every operation, not only mints, reports 85 and reverts.
        assertEq(token.detectTransferRestriction(ADDRESS1, ADDRESS2, 1), CODE_RULE_NOT_BOUND);
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 1), CODE_RULE_NOT_BOUND);
        assertEq(engine.messageForTransferRestriction(CODE_RULE_NOT_BOUND), TEXT_RULE_NOT_BOUND);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);
    }
}
