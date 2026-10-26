// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";
import {ConditionalTransferHandler} from "./ConditionalTransferHandler.sol";
import {MintAllowanceHandler} from "./MintAllowanceHandler.sol";
import {MaxTotalSupplyHandler} from "./MaxTotalSupplyHandler.sol";
import {IssuanceCapHandler} from "./IssuanceCapHandler.sol";
import {RuleMaxTotalSupplyBase} from "src/rules/validation/abstract/base/RuleMaxTotalSupplyBase.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";

/**
 * @title ConditionalTransferInvariants
 * @notice Stateful invariant suite over {RuleConditionalTransferLight}'s approval state machine.
 * @dev Covers INV-5 (approvals are conserved and never underflow).
 */
contract ConditionalTransferInvariants is Test {
    address private constant ADMIN = address(1);

    RuleConditionalTransferLight private rule;
    ConditionalTransferHandler private handler;

    function setUp() public {
        vm.startPrank(ADMIN);
        rule = new RuleConditionalTransferLight(ADMIN);
        handler = new ConditionalTransferHandler(rule);

        // The handler acts as the operator (approve/cancel) and as the bound entity (execute).
        rule.grantRole(rule.OPERATOR_ROLE(), address(handler));
        rule.bindToken(address(handler));
        vm.stopPrank();

        // Restrict fuzzing to the handler's own actions; without this the fuzzer would also call
        // the public functions the handler inherits from forge-std's Test.
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = ConditionalTransferHandler.approve.selector;
        selectors[1] = ConditionalTransferHandler.cancel.selector;
        selectors[2] = ConditionalTransferHandler.execute.selector;
        selectors[3] = ConditionalTransferHandler.executeMintOrBurn.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /**
     * @notice INV-5: every recorded approval is either still outstanding, cancelled, or consumed —
     *         exactly once. Approvals are never double-spent, never lost, and never underflow.
     *
     *         totalApproved - totalCancelled - totalExecuted == Σ approvalCounts
     *
     *         Because mint/burn callbacks are fired by the handler but deliberately not counted in
     *         `totalExecuted`, this equality also proves mint/burn never consume an approval.
     */
    function invariant_approvalConservation() public view {
        uint256 approved = handler.totalApproved();
        uint256 cancelled = handler.totalCancelled();
        uint256 executed = handler.totalExecuted();

        assertGe(approved, cancelled + executed, "consumed more approvals than were ever recorded");
        assertEq(approved - cancelled - executed, handler.sumApprovalCounts(), "approval accounting drifted");
    }

    /**
     * @notice INV-6 (corollary): an outstanding approval count can never exceed the number of
     *         approvals recorded for that tuple, so no tuple can be over-consumed.
     */
    function invariant_noApprovalExceedsTotalRecorded() public view {
        assertLe(handler.sumApprovalCounts(), handler.totalApproved(), "outstanding exceeds recorded");
    }
}

/**
 * @title MintAllowanceInvariants
 * @notice Stateful invariant suite over {RuleMintAllowance}'s quota accounting.
 * @dev Covers INV-7 (quota is exact, monotonically consumed, never underflows).
 */
contract MintAllowanceInvariants is Test {
    address private constant ADMIN = address(1);

    RuleMintAllowance private rule;
    MintAllowanceHandler private handler;

    function setUp() public {
        vm.startPrank(ADMIN);
        rule = new RuleMintAllowance(ADMIN);
        handler = new MintAllowanceHandler(rule);

        // The handler acts as the allowance operator and as the bound entity (mint callbacks).
        rule.grantRole(rule.ALLOWANCE_OPERATOR_ROLE(), address(handler));
        rule.bindToken(address(handler));
        vm.stopPrank();

        // Restrict fuzzing to the handler's own actions (see note in ConditionalTransferInvariants).
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = MintAllowanceHandler.setAllowance.selector;
        selectors[1] = MintAllowanceHandler.increase.selector;
        selectors[2] = MintAllowanceHandler.decrease.selector;
        selectors[3] = MintAllowanceHandler.mint.selector;
        selectors[4] = MintAllowanceHandler.regularTransfer.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /**
     * @notice INV-7: the on-chain quota exactly mirrors the expected value after any interleaving of
     *         set / increase / decrease / mint / regular-transfer. Because `regularTransfer` never
     *         updates the ghost, this equality also proves non-mint transfers do not touch the quota.
     */
    function invariant_allowanceMatchesGhost() public view {
        uint256 count = handler.minterCount();
        for (uint256 i = 0; i < count; ++i) {
            (address minter, uint256 expected) = handler.minterAt(i);
            assertEq(rule.mintAllowance(minter), expected, "mint allowance drifted from expected");
        }
    }

    /**
     * @notice INV-7: a minter can never mint more in total than was ever credited to it.
     */
    function invariant_mintedNeverExceedsCredited() public view {
        assertLe(handler.totalMinted(), handler.totalCredited(), "minted more than was ever granted");
    }
}

/**
 * @title SupplyCapInvariantsBase
 * @notice The invariants shared by every supply-cap rule, on a real CMTAT token with the rule set directly
 * on it (`setRuleEngine(rule)`). The concrete suites differ only in the rule, the handler and the expected
 * remaining room ({_expectedHeadroom}).
 */
abstract contract SupplyCapInvariantsBase is Test {
    address internal constant ADMIN = address(1);
    uint256 internal constant INITIAL_CAP = 1000;
    uint8 internal constant TRANSFER_OK = 0;

    CMTATStandardStandalone internal token;
    RuleMaxTotalSupplyBase internal rule;
    MaxTotalSupplyHandler internal handler;

    /// @dev Restrict fuzzing to the handler's own actions.
    function _targetHandler() internal {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = MaxTotalSupplyHandler.mint.selector;
        selectors[1] = MaxTotalSupplyHandler.burnAndMint.selector;
        selectors[2] = MaxTotalSupplyHandler.burn.selector;
        selectors[3] = MaxTotalSupplyHandler.forcedBurn.selector;
        selectors[4] = MaxTotalSupplyHandler.transfer.selector;
        selectors[5] = MaxTotalSupplyHandler.setCap.selector;
        selectors[6] = MaxTotalSupplyHandler.mintAtBoundary.selector;
        selectors[7] = MaxTotalSupplyHandler.increaseCap.selector;
        selectors[8] = MaxTotalSupplyHandler.decreaseCap.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /// @dev What `remainingMintable()` must report, computed independently of the rule.
    function _expectedHeadroom() internal view virtual returns (uint256) {
        uint256 supply = token.totalSupply();
        uint256 cap = rule.maxTotalSupply();
        return supply >= cap ? 0 : cap - supply;
    }

    /**
     * @notice Safety: no mint that went through exceeded the cap in force at that moment.
     */
    function invariant_noMintBreachedTheCap() public view {
        assertEq(handler.ghostBreaches(), 0, "a mint went through above the cap");
    }

    /**
     * @notice Liveness: every mint that fitted under the cap went through. A rule that rejected too much
     * would satisfy the safety invariant trivially; this one rules that out.
     */
    function invariant_noFittingMintWasRejected() public view {
        assertEq(handler.ghostFalseRejections(), 0, "a mint that fitted was rejected");
    }

    /**
     * @notice A rejected mint fails with the rule's own error, never with an unrelated revert.
     */
    function invariant_mintsFailOnlyWithTheRuleError() public view {
        assertEq(handler.ghostUnexpectedReverts(), 0, "a mint failed for an unexpected reason");
    }

    /**
     * @notice `remainingMintable()` always equals the independently computed room. Forced burns bypass the
     * engine, so this also proves the rule never holds a stale view of the supply.
     */
    function invariant_remainingMintableMatchesLiveSupply() public view {
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, TRANSFER_OK, "supply unexpectedly unreadable");
        assertEq(headroom, _expectedHeadroom(), "headroom drifted from the expected room");
    }

    /**
     * @notice The pre-flight view accepts a mint of exactly the headroom (when there is any) and rejects one
     * unit more, both on the rule and through the token's own view.
     */
    function invariant_preflightAgreesWithHeadroom() public view {
        (, uint256 headroom) = rule.remainingMintable();
        address to = handler.actor(0);
        if (headroom > 0) {
            assertEq(rule.detectTransferRestriction(address(0), to, headroom), TRANSFER_OK, "headroom rejected");
            assertEq(token.detectTransferRestriction(address(0), to, headroom), TRANSFER_OK, "token: headroom rejected");
        }
        assertTrue(rule.detectTransferRestriction(address(0), to, headroom + 1) != TRANSFER_OK, "headroom + 1 accepted");
    }
}

/**
 * @title MaxTotalSupplyInvariants
 * @notice {SupplyCapInvariantsBase} over {RuleMaxTotalSupply}: the cap bounds the live supply.
 */
contract MaxTotalSupplyInvariants is SupplyCapInvariantsBase {
    function setUp() public {
        token = new CMTATDeployment().cmtat();
        rule = new RuleMaxTotalSupply(ADMIN, address(token), INITIAL_CAP);
        vm.prank(ADMIN);
        token.setRuleEngine(IRuleEngine(address(rule)));
        // The handler pranks ADMIN for every privileged call, so it needs no role of its own.
        handler = new MaxTotalSupplyHandler(token, rule);
        _targetHandler();
    }
}

/**
 * @title IssuanceCapInvariants
 * @notice {SupplyCapInvariantsBase} over {RuleIssuanceCap}, plus the counter's own accounting.
 */
contract IssuanceCapInvariants is SupplyCapInvariantsBase {
    RuleIssuanceCap private issuanceRule;

    function setUp() public {
        token = new CMTATDeployment().cmtat();
        issuanceRule = new RuleIssuanceCap(ADMIN, address(token), INITIAL_CAP, 0);
        rule = issuanceRule;
        vm.startPrank(ADMIN);
        token.setRuleEngine(IRuleEngine(address(issuanceRule)));
        issuanceRule.bindToken(address(token));
        vm.stopPrank();
        handler = new IssuanceCapHandler(token, issuanceRule);
        _targetHandler();
    }

    function _expectedHeadroom() internal view override returns (uint256) {
        uint256 cap = rule.maxTotalSupply();
        uint256 issued = IssuanceCapHandler(address(handler)).ghostIssued();
        uint256 counterRoom = issued >= cap ? 0 : cap - issued;
        uint256 liveRoom = super._expectedHeadroom();
        return counterRoom < liveRoom ? counterRoom : liveRoom;
    }

    /**
     * @notice The counter is exact: it equals the independently tracked sum of accepted mints, so burns,
     * forced burns, transfers and cap changes never move it.
     */
    function invariant_totalIssuedMatchesGhost() public view {
        assertEq(issuanceRule.totalIssued(), IssuanceCapHandler(address(handler)).ghostIssued(), "counter drifted");
    }

    /**
     * @notice Cumulative issuance covers the outstanding supply, since every mint was counted.
     */
    function invariant_issuedCoversSupply() public view {
        assertGe(issuanceRule.totalIssued(), token.totalSupply(), "supply exceeds counted issuance");
    }
}
