// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";

import {RuleEngine} from "RuleEngine/deployment/RuleEngine.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";

import {IdentityRegistryMock} from "src/mocks/IdentityRegistryMock.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {MockERC20WithTransferContext} from "src/mocks/MockERC20WithTransferContext.sol";

import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";

/**
 * @title ThreatModelTests
 * @notice Proof-of-concept tests backing the findings recorded in `CLAUDE_AUDIT.md`.
 * @dev Each test names the threat ID it exercises. Tests that assert a *current, undesirable*
 *      behaviour are named `*_CurrentBehaviour` so a future fix flags them for update.
 */
contract ThreatModelTests is Test, HelperContract {
    /**
     * @dev Redeclared locally: `HelperContract` already inherits the single-token
     *      `RuleConditionalTransferLightInvariantStorage`, whose constants clash with the
     *      multi-token variant's.
     */
    error RuleConditionalTransferLightMultiToken_TransferNotApproved();

    address private constant MINTER = address(10);
    address private constant FORWARDER = address(0);

    /*//////////////////////////////////////////////////////////////
        IR-1 — RuleIdentityRegistry is ERC-3643 conformant  [FIXED — I-1]
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice IR-1 (regression): ERC-3643 states that `mint` "only require[s] the receiver to be
     *         whitelisted and verified on the Identity Registry". The minter is NOT screened, so a
     *         mint to a verified recipient succeeds even when the minter's own EOA is unregistered.
     *         This previously reverted with CODE_ADDRESS_SPENDER_NOT_VERIFIED (finding F-1).
     */
    function test_IR1_MintSucceedsWhenMinterNotVerified() public {
        IdentityRegistryMock registry = new IdentityRegistryMock();
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, address(cmtatContract));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleIdentityRegistry = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry), false, false);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleIdentityRegistry);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.setRuleEngine(ruleEngineMock);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.grantRole(keccak256("MINTER_ROLE"), MINTER);

        // The recipient is KYC-verified. The minter (the issuer's operational EOA) is NOT.
        registry.setVerified(ADDRESS1, true);

        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 100);
    }

    /**
     * @notice IR-1 (regression): the receiver check IS mandated — a mint to an unverified recipient
     *         is still rejected.
     */
    function test_IR1_MintStillRejectedWhenRecipientNotVerified() public {
        IdentityRegistryMock registry = new IdentityRegistryMock();
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, address(cmtatContract));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleIdentityRegistry = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry), false, false);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleIdentityRegistry);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.setRuleEngine(ruleEngineMock);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.grantRole(keccak256("MINTER_ROLE"), MINTER);

        registry.setVerified(MINTER, true); // minter verified, RECIPIENT is not

        vm.prank(MINTER);
        vm.expectRevert();
        cmtatContract.mint(ADDRESS1, 100);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 0);
    }

    /**
     * @notice IR-1 (regression): the sender is not screened by default, so a DE-LISTED HOLDER can
     *         still exit their position to a verified counterparty — the reason ERC-3643 checks only
     *         the receiver. Previously the holder was trapped.
     */
    function test_IR1_DelistedHolderCanStillExit() public {
        IdentityRegistryMock registry = new IdentityRegistryMock();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleIdentityRegistry = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry), false, false);

        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);
        assertEq(ruleIdentityRegistry.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);

        // ADDRESS1's identity lapses (claim expired / identity revoked).
        registry.setVerified(ADDRESS1, false);

        // They can no longer RECEIVE...
        assertEq(ruleIdentityRegistry.detectTransferRestriction(ADDRESS2, ADDRESS1, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
        // ...but they can still SEND to a verified counterparty, i.e. exit their position.
        assertEq(ruleIdentityRegistry.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
    }

    /**
     * @notice IR-1 (contrast, unchanged): RuleWhitelist with `checkSpender = true` also exempts mints
     *         from the spender check. The two rules now agree.
     */
    function test_IR1_WhitelistExemptsMintFromSpenderCheck() public {
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, address(cmtatContract));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, true, true);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleWhitelist);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.setRuleEngine(ruleEngineMock);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.grantRole(keccak256("MINTER_ROLE"), MINTER);

        assertEq(ruleWhitelist.isAddressListed(MINTER), false);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 100);
    }

    /*//////////////////////////////////////////////////////////////
        MTS-1 — RuleMaxTotalSupply views return a code (never revert) on overflow  [FIXED — I-3]
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice MTS-1 (regression): `detectTransferRestriction`, `canTransfer` and
     *         `detectTransferRestrictionFrom` are ERC-1404 / ERC-3643 views that must never revert.
     *         After the overflow-safe fix (I-3), a `value` that would overflow `currentSupply + value`
     *         returns CODE_MAX_TOTAL_SUPPLY_EXCEEDED (resp. `false`) instead of panicking.
     */
    function test_MTS1_DetectTransferRestrictionReturnsCodeOnOverflow() public {
        TotalSupplyMock token = new TotalSupplyMock();
        token.setTotalSupply(1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleMaxTotalSupply = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), 1000);

        assertEq(
            ruleMaxTotalSupply.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, type(uint256).max),
            CODE_MAX_TOTAL_SUPPLY_EXCEEDED
        );
        assertEq(ruleMaxTotalSupply.canTransfer(ZERO_ADDRESS, ADDRESS1, type(uint256).max), false);
        assertEq(
            ruleMaxTotalSupply.detectTransferRestrictionFrom(ADDRESS3, ZERO_ADDRESS, ADDRESS1, type(uint256).max),
            CODE_MAX_TOTAL_SUPPLY_EXCEEDED
        );
    }

    /**
     * @notice MTS-1 (regression): the overflow-safe view returns a code through a RuleEngine too,
     *         so the token-level ERC-1404 view of any CMTAT wired to this rule no longer reverts.
     */
    function test_MTS1_OverflowReturnsCodeThroughRuleEngine() public {
        TotalSupplyMock token = new TotalSupplyMock();
        token.setTotalSupply(1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleMaxTotalSupply = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), 1000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleMaxTotalSupply);

        assertEq(
            ruleEngineMock.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, type(uint256).max),
            CODE_MAX_TOTAL_SUPPLY_EXCEEDED
        );
    }

    /**
     * @notice MTS-1 (regression): fuzz the full uint256 domain, including the overflow region.
     *         The view must return the correct code and never revert.
     */
    function testFuzz_MTS1_DetectRestrictionNeverReverts(uint256 currentSupply, uint256 value, uint256 maxSupply)
        public
    {
        TotalSupplyMock token = new TotalSupplyMock();
        token.setTotalSupply(currentSupply);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleMaxTotalSupply = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), maxSupply);

        uint8 code = ruleMaxTotalSupply.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, value);
        bool exceeds = currentSupply > maxSupply || value > maxSupply - currentSupply;
        assertEq(code, exceeds ? CODE_MAX_TOTAL_SUPPLY_EXCEEDED : TRANSFER_OK);
    }

    /**
     * @notice MTS-1 (kept): the non-overflowing region still returns the correct code.
     */
    function testFuzz_MTS1_DetectRestrictionBelowOverflow(uint256 currentSupply, uint256 value) public {
        currentSupply = bound(currentSupply, 0, type(uint128).max);
        value = bound(value, 0, type(uint256).max - currentSupply);

        TotalSupplyMock token = new TotalSupplyMock();
        token.setTotalSupply(currentSupply);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleMaxTotalSupply = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), type(uint128).max);

        uint8 code = ruleMaxTotalSupply.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, value);
        bool exceeds = currentSupply + value > uint256(type(uint128).max);
        assertEq(code, exceeds ? CODE_MAX_TOTAL_SUPPLY_EXCEEDED : TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
        CTL-1 — approveAndTransferIfAllowed behind a RuleEngine  [FIXED — I-5]
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice CTL-1 (regression): the helper WORKS behind a RuleEngine once the two binding roles are
     *         split — `bindToken(token)` for the ERC-20 target, `bindRuleEngine(engine)` for the
     *         authorized caller. It previously could not work at all: a single binding slot had to be
     *         both, and behind an engine those are different addresses (finding F-3).
     *         End-to-end coverage lives in
     *         `test/RuleConditionalTransferLight/RuleConditionalTransferLightBindRuleEngine.t.sol`.
     */
    function test_CTL1_ApproveAndTransferIfAllowedWorksOnceEngineIsBound() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);

        MockERC20WithTransferContext token = new MockERC20WithTransferContext("Token", "TKN");

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.bindToken(address(token));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.bindRuleEngine(address(ruleEngineMock));

        // Both are authorized executors; the ERC-20 target is the TOKEN, never the engine.
        assertTrue(ruleConditionalTransferLight.isTransferExecutor(address(token)));
        assertTrue(ruleConditionalTransferLight.isTransferExecutor(address(ruleEngineMock)));
        assertEq(ruleConditionalTransferLight.getTokenBound(), address(token));
    }

    /**
     * @notice CTL-1 (regression): the two unsupported wirings still fail loudly.
     *         Binding ONLY the engine leaves `getTokenBound()` a non-ERC-20, so the helper reverts;
     *         binding ONLY the token leaves the engine unauthorized, so it cannot consume approvals.
     */
    function test_CTL1_UnsupportedWiringsStillFail() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS);

        // (a) engine bound as the "token": IERC20(engine).allowance(...) has no such function.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLight engineOnly = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        engineOnly.bindToken(address(ruleEngineMock));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert();
        engineOnly.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);

        // (b) token bound but engine NOT bound: the engine is not an authorized executor.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLight tokenOnly = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenOnly.bindToken(ADDRESS1);
        assertFalse(tokenOnly.isTransferExecutor(address(ruleEngineMock)));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenOnly.approveTransfer(ADDRESS2, ADDRESS3, 10);
        vm.prank(address(ruleEngineMock));
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleConditionalTransferLight_TransferExecutorUnauthorized.selector, address(ruleEngineMock)
            )
        );
        tokenOnly.transferred(ADDRESS2, ADDRESS3, 10);
    }

    /**
     * @notice CTL-1 (documented caveat, NOT fixed): `RuleConditionalTransferLight` keys approvals on
     *         `(from, to, value)` with NO token dimension. A `RuleEngine` is multi-tenant, so if the
     *         bound engine serves several tokens they all share one approval bucket: an approval
     *         recorded for token A is consumable by a token-B transfer relayed through the same engine.
     *
     *         This is inherent to the single-token rule (it is why the MultiToken variant exists) and
     *         is why `bindRuleEngine` documents "bind ONLY an engine that serves this one token".
     *         Pinned here so the constraint is a tested property rather than a doc claim.
     */
    function test_CTL1_ApprovalsAreNotTokenScopedBehindAMultiTenantEngine_CurrentBehaviour() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS);
        RuleConditionalTransferLight rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1); // token A
        rule.bindRuleEngine(address(engine));
        rule.approveTransfer(ADDRESS2, ADDRESS3, 100); // intended for token A
        vm.stopPrank();

        assertEq(rule.approvedCount(ADDRESS2, ADDRESS3, 100), 1);

        // The engine relays a transfer of a DIFFERENT token it also serves. The rule cannot tell,
        // and consumes the token-A approval.
        vm.prank(address(engine));
        rule.transferred(ADDRESS2, ADDRESS3, 100);

        assertEq(rule.approvedCount(ADDRESS2, ADDRESS3, 100), 0);
    }

    /**
     * @notice CTL-1: only the bound entity may consume an approval.
     */
    function test_CTL1_UnboundCallerCannotConsumeApproval() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.bindToken(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.approveTransfer(ADDRESS2, ADDRESS3, 10);

        vm.prank(ATTACKER);
        vm.expectRevert();
        ruleConditionalTransferLight.transferred(ADDRESS2, ADDRESS3, 10);

        assertEq(ruleConditionalTransferLight.approvedCount(ADDRESS2, ADDRESS3, 10), 1);
    }

    /*//////////////////////////////////////////////////////////////
        CTL-2 — MultiToken approval-key mismatch under a RuleEngine
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice CTL-2: the multi-token rule stores approvals under the caller-supplied `token`
     *         but consumes them under `msg.sender`. Behind a RuleEngine those differ, so a
     *         token-keyed approval is never consumable and remains permanently stale.
     */
    function test_CTL2_MultiTokenApprovalKeyMismatchLeavesStaleApproval_CurrentBehaviour() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLightMultiToken rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);

        MockERC20WithTransferContext token = new MockERC20WithTransferContext("Token", "TKN");

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(engine));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));

        // Operator approves the transfer for the *token*, as the public API suggests.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(token), ADDRESS2, ADDRESS3, 10);
        assertEq(rule.approvedCount(address(token), ADDRESS2, ADDRESS3, 10), 1);

        // The RuleEngine is the actual caller of `transferred()`, so the key does not match.
        vm.prank(address(engine));
        vm.expectRevert(RuleConditionalTransferLightMultiToken_TransferNotApproved.selector);
        rule.transferred(ADDRESS2, ADDRESS2, ADDRESS3, 10);

        // The token-keyed approval is still there and can never be consumed in this topology.
        assertEq(rule.approvedCount(address(token), ADDRESS2, ADDRESS3, 10), 1);
        assertEq(rule.approvedCount(address(engine), ADDRESS2, ADDRESS3, 10), 0);
    }

    /**
     * @notice CTL-2: engine-keyed approvals ARE consumable, confirming the key really is
     *         `msg.sender`. In a RuleEngine bound to several tokens this collapses the
     *         per-token isolation the rule's name and documentation advertise.
     */
    function test_CTL2_EngineKeyedApprovalIsSharedAcrossTokens_CurrentBehaviour() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLightMultiToken rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(engine));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(engine), ADDRESS2, ADDRESS3, 10);

        // Any token routed through this engine consumes the same approval bucket.
        vm.prank(address(engine));
        rule.transferred(ADDRESS2, ADDRESS2, ADDRESS3, 10);
        assertEq(rule.approvedCount(address(engine), ADDRESS2, ADDRESS3, 10), 0);
    }

    /**
     * @notice CTL-2: `detectTransferRestriction` keys on `msg.sender`, so an off-chain
     *         integrator (or any caller that is not a bound token) always sees "not approved"
     *         even for an approved transfer. Fail-closed, but the ERC-1404 view carries no signal.
     */
    function test_CTL2_DetectTransferRestrictionIsMsgSenderDependent_CurrentBehaviour() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLightMultiToken rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, ADDRESS3, 10);

        // Called by the bound token: approved.
        vm.prank(ADDRESS1);
        assertEq(rule.detectTransferRestriction(ADDRESS2, ADDRESS3, 10), TRANSFER_OK);

        // Called by anybody else (e.g. an off-chain `eth_call` from a wallet): not approved.
        vm.prank(ATTACKER);
        assertEq(rule.detectTransferRestriction(ADDRESS2, ADDRESS3, 10), CODE_TRANSFER_REQUEST_NOT_APPROVED);
    }

    /*//////////////////////////////////////////////////////////////
        BIND-1 — state survives unbind/rebind
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice BIND-1: `unbindToken` does not clear `approvalCounts`. An approval granted for
     *         token A survives a rebind to token B and is consumable by B.
     */
    function test_BIND1_ConditionalTransferApprovalSurvivesRebind_CurrentBehaviour() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.bindToken(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.approveTransfer(ADDRESS2, ADDRESS3, 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.unbindToken(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleConditionalTransferLight.bindToken(ATTACKER);

        assertEq(ruleConditionalTransferLight.approvedCount(ADDRESS2, ADDRESS3, 10), 1);
        vm.prank(ATTACKER);
        ruleConditionalTransferLight.transferred(ADDRESS2, ADDRESS3, 10);
        assertEq(ruleConditionalTransferLight.approvedCount(ADDRESS2, ADDRESS3, 10), 0);
    }

    /**
     * @notice BIND-1: `unbindToken` does not clear `mintAllowance` either.
     */
    function test_BIND1_MintAllowanceSurvivesRebind_CurrentBehaviour() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleMintAllowance rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, 1000);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindToken(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ATTACKER);

        assertEq(rule.mintAllowance(MINTER), 1000);
        vm.prank(ATTACKER);
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 400);
        assertEq(rule.mintAllowance(MINTER), 600);
    }

    /*//////////////////////////////////////////////////////////////
        MA-1 — RuleMintAllowance eligibility views carry no signal
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice MA-1: `canTransfer` / `detectTransferRestriction` are hardcoded to "allowed",
     *         so a pre-flight check disagrees with the enforcement path, which reverts.
     */
    function test_MA1_HardcodedEligibilityViewsDisagreeWithEnforcement_CurrentBehaviour() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleMintAllowance rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);

        assertEq(rule.mintAllowance(MINTER), 0);

        // Pre-flight says "allowed" even though the minter has zero quota.
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 100), TRANSFER_OK);
        assertEq(rule.canTransfer(ZERO_ADDRESS, ADDRESS2, 100), true);

        // Only the spender-aware view carries the real answer.
        assertEq(rule.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS2, 100), false);

        // Enforcement reverts.
        vm.prank(ADDRESS1);
        vm.expectRevert();
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS2, 100);
    }

    /**
     * @notice MA-1, one level up: the hardcoded "allowed" is not confined to the rule. It propagates
     *         through the RuleEngine's aggregate and out to the token's own ERC-1404 views, which is
     *         the API an integrator actually calls (`CLAUDE_ANALYSIS.md` F-6).
     * @dev `RuleEngineBase._detectTransferRestriction` aggregates by calling each rule's 3-argument
     *      view and returning the first non-zero code; this rule always contributes `0`. CMTAT's
     *      `ValidationModuleERC1404` then forwards the token's views to the engine. The 4-argument
     *      chain is unaffected at every level and carries the real answer.
     *
     *      `_CurrentBehaviour`: this asserts what the audit considers wrong. If the rule, the engine
     *      or CMTAT is ever changed to close the gap, this test must fail — at which point update it
     *      together with `CLAUDE_ANALYSIS.md` F-6, `CLAUDE_AUDIT.md` F-7 and the two documentation tables.
     */
    function test_MA1_EngineAndTokenInheritTheHardcodedAllowedView_CurrentBehaviour() public {
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, address(cmtatContract));
        RuleMintAllowance rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(ruleEngineMock));
        ruleEngineMock.addRule(rule);
        cmtatContract.setRuleEngine(ruleEngineMock);
        cmtatContract.grantRole(keccak256("MINTER_ROLE"), MINTER);
        vm.stopPrank();

        // MINTER has no quota at all: every mint by them will revert.
        assertEq(rule.mintAllowance(MINTER), 0);

        // ENGINE level — the aggregate reports "allowed".
        assertEq(ruleEngineMock.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 100), TRANSFER_OK);
        assertTrue(ruleEngineMock.canTransfer(ZERO_ADDRESS, ADDRESS2, 100));

        // TOKEN level — CMTAT forwards to the engine, so it reports "allowed" too.
        assertEq(cmtatContract.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 100), TRANSFER_OK);
        assertTrue(cmtatContract.canTransfer(ZERO_ADDRESS, ADDRESS2, 100));

        // The 4-argument chain carries the real answer at BOTH levels.
        assertEq(
            ruleEngineMock.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS2, 100),
            CODE_MINTER_ALLOWANCE_EXCEEDED
        );
        assertFalse(ruleEngineMock.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS2, 100));
        assertEq(
            cmtatContract.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS2, 100),
            CODE_MINTER_ALLOWANCE_EXCEEDED
        );

        // Enforcement agrees with the 4-arg views, not with the 3-arg ones.
        vm.prank(MINTER);
        vm.expectRevert();
        cmtatContract.mint(ADDRESS2, 100);
    }

    /**
     * @notice MA-1: quota accounting never underflows and always matches consumed amounts.
     */
    function testFuzz_MA1_MintAllowanceAccountingIsExact(uint128 quota, uint128 mintA, uint128 mintB) public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleMintAllowance rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMintAllowance(MINTER, quota);

        uint256 consumed = 0;
        uint128[2] memory mints = [mintA, mintB];
        for (uint256 i = 0; i < mints.length; ++i) {
            vm.prank(ADDRESS1);
            if (uint256(mints[i]) > uint256(quota) - consumed) {
                vm.expectRevert();
                rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS2, mints[i]);
            } else {
                rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS2, mints[i]);
                consumed += mints[i];
            }
        }
        assertEq(rule.mintAllowance(MINTER), uint256(quota) - consumed);
    }

    /*//////////////////////////////////////////////////////////////
        WW-1 / WW-2 — RuleWhitelistWrapper child-rule handling
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice WW-1: the wrapper's OR semantics span child rules per address, so a transfer is
     *         allowed when `from` is whitelisted in one child and `to` in a different child.
     *         No child rule on its own would allow it.
     */
    function test_WW1_CrossRuleOrAllowsTransferNoSingleChildAllows() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist childA = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, false);
        RuleWhitelist childB = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, false);
        childA.addAddress(ADDRESS1);
        childB.addAddress(ADDRESS2);

        RuleWhitelistWrapper wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);
        wrapper.addRule(IRule(address(childA)));
        wrapper.addRule(IRule(address(childB)));
        vm.stopPrank();

        // Neither child alone permits ADDRESS1 -> ADDRESS2.
        assertEq(childA.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_TO_NOT_WHITELISTED);
        assertEq(childB.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_FROM_NOT_WHITELISTED);

        // The wrapper does.
        assertEq(wrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
        assertEq(wrapper.canTransfer(ADDRESS1, ADDRESS2, 10), true);
    }

    /**
     * @notice WW-2: **FIXED.** The wrapper now ERC-165-checks its children, so a conformant `IRule`
     *         that is not an address list is rejected at `addRule` instead of being accepted and
     *         bricking later transfer checks.
     * @dev This test formerly asserted the broken behaviour and was named `..._CurrentBehaviour`:
     *      the wrapper accepted `RuleMaxTotalSupply` as a child, and any check whose targets were
     *      not already resolved by an earlier child reverted on the blind `areAddressesListed` call.
     *      The early exit in `_detectTransferRestrictionForTargets` made that input-dependent —
     *      `(ADDRESS1, ADDRESS2)` still passed while `(ADDRESS1, ADDRESS3)` reverted — which is what
     *      made it hard to notice.
     *
     *      The guard requires {IAddressListBatchQuery}, the single function the wrapper actually
     *      calls, rather than the whole of `IAddressList`. Nethermind AuditAgent NM-18, audit F-5.
     */
    function test_WW2_NonAddressListChildRuleIsRejectedAtAddRule() public {
        TotalSupplyMock token = new TotalSupplyMock();
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist childA = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, false);
        childA.addAddress(ADDRESS1);
        childA.addAddress(ADDRESS2);

        RuleWhitelistWrapper wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);
        wrapper.addRule(IRule(address(childA)));
        assertEq(wrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);

        // RuleMaxTotalSupply is a valid IRule but exposes no `areAddressesListed`.
        RuleMaxTotalSupply notAnAddressList = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), 1000);
        vm.expectRevert(
            abi.encodeWithSelector(RuleWhitelistWrapper_ChildIsNotAnAddressList.selector, address(notAnAddressList))
        );
        wrapper.addRule(IRule(address(notAnAddressList)));
        vm.stopPrank();

        // The wrapper is intact: the pair that used to revert now answers normally.
        assertEq(wrapper.detectTransferRestriction(ADDRESS1, ADDRESS3, 10), CODE_ADDRESS_TO_NOT_WHITELISTED);
        assertEq(wrapper.rulesCount(), 1, "the bad child was never added");
    }

    /**
     * @notice WW-2: the guard also refuses a nested wrapper, which would otherwise brick the parent.
     * @dev `RuleWhitelistWrapper` aggregates children but does not itself implement
     *      `areAddressesListed`, so it cannot be a child of another wrapper. Before the guard that
     *      configuration was accepted and reverted every transfer through the parent; now it is
     *      refused up front. Enabling nesting is a separate change (NM-19).
     */
    function test_WW2_NestedWrapperIsRejectedAtAddRule() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelistWrapper inner = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);
        RuleWhitelistWrapper outer = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);

        vm.expectRevert(abi.encodeWithSelector(RuleWhitelistWrapper_ChildIsNotAnAddressList.selector, address(inner)));
        outer.addRule(IRule(address(inner)));
        vm.stopPrank();
    }

    /**
     * @notice WW-2: the guard cannot check POLARITY — a blacklist child is still accepted (NM-20).
     * @dev `RuleBlacklist` answers `areAddressesListed` just as faithfully as a whitelist and
     *      advertises the same interface id, because the interface genuinely is the same. ERC-165
     *      therefore cannot distinguish an allow-list from a deny-list, and this configuration
     *      remains the rules manager's responsibility. Pinned so the limit of the NM-18 guard is
     *      explicit rather than assumed.
     */
    function test_WW2_GuardCannotRejectAnInvertedPolarityChild_CurrentBehaviour() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleBlacklist denyList = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, FORWARDER);
        denyList.addAddress(ATTACKER);

        RuleWhitelistWrapper wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);
        wrapper.addRule(IRule(address(denyList))); // accepted: the interface is satisfied
        vm.stopPrank();

        // ...and the blacklisted address is now reported as an eligible investor.
        assertTrue(wrapper.isVerified(ATTACKER), "NM-20: polarity is not expressible in IAddressList");
    }

    /**
     * @notice WW-2: a wrapper with no child rules rejects every transfer (fail-closed).
     */
    function test_WW2_EmptyWrapperFailsClosed() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelistWrapper wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);
        assertEq(wrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_FROM_NOT_WHITELISTED);
        assertEq(wrapper.isVerified(ADDRESS1), false);
    }

    /*//////////////////////////////////////////////////////////////
        HASH-1 — approval hash injectivity
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice HASH-1: distinct `(from, to, value)` tuples must never share an approval bucket.
     *         Guards the hand-rolled `_transferHash` assembly against packing collisions.
     */
    function testFuzz_HASH1_ApprovalBucketsAreDistinct(address from, address to, uint256 value, uint256 otherValue)
        public
    {
        vm.assume(from != to);
        vm.assume(value != otherValue);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleConditionalTransferLight rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(from, to, value);

        assertEq(rule.approvedCount(from, to, value), 1);
        assertEq(rule.approvedCount(to, from, value), 0);
        assertEq(rule.approvedCount(from, to, otherValue), 0);
    }
}
