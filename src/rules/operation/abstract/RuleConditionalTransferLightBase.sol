// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643ComplianceRead, IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {ERC3643ComplianceModule} from "RuleEngine/modules/ERC3643ComplianceModule.sol";
import {TokenBindingModule} from "RuleEngine/modules/TokenBindingModule.sol";
import {ITokenBinding} from "RuleEngine/interfaces/ITokenBinding.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RuleConditionalTransferLightApprovalBase} from "./RuleConditionalTransferLightApprovalBase.sol";
import {VersionModule} from "../../../modules/VersionModule.sol";

/**
 * @title RuleConditionalTransferLightBase
 * @dev Wires the approval state machine into the ERC-3643 / ERC-1404 / IRule compliance
 *      interface layer and enforces single-token binding.
 */
abstract contract RuleConditionalTransferLightBase is
    VersionModule,
    ERC3643ComplianceModule,
    RuleConditionalTransferLightApprovalBase,
    IRule
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                             STATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice RuleEngine additionally authorized to call the transfer execution hooks.
     * @dev Binding is deliberately split into two independent roles:
     *
     *      - {bindToken}      — the **ERC-20 token** this rule acts on. It is the token that
     *                           {approveAndTransferIfAllowed} calls `safeTransferFrom` on, and it may
     *                           call `transferred` itself (direct-binding topology).
     *      - {bindRuleEngine} — a **RuleEngine** allowed to call `transferred` on this rule. Under the
     *                           RuleEngine topology the engine, not the token, is the caller of the
     *                           compliance hooks.
     *
     *      Conflating the two was the bug: with a single slot you had to choose between authorizing
     *      the engine (which broke {approveAndTransferIfAllowed}, since the engine is not an ERC-20)
     *      and pointing at the token (which left the engine unauthorized, reverting every transfer).
     *      Binding both makes the helper usable in either topology.
     */
    address public ruleEngine;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Compliance hook invoked when tokens are created (minted); consumes an approval if applicable.
     * @param to The recipient of the created tokens.
     * @param value The amount of tokens created.
     */
    function created(address to, uint256 value) external onlyBoundToken {
        _transferred(address(0), to, value);
    }

    /**
     * @notice Compliance hook invoked when tokens are destroyed (burned); consumes an approval if applicable.
     * @param from The holder whose tokens are destroyed.
     * @param value The amount of tokens destroyed.
     */
    function destroyed(address from, uint256 value) external onlyBoundToken {
        _transferred(from, address(0), value);
    }

    /**
     * @inheritdoc IRule
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override(IRule) returns (bool) {
        return restrictionCode == CODE_TRANSFER_REQUEST_NOT_APPROVED;
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        external
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_TRANSFER_REQUEST_NOT_APPROVED) {
            return TEXT_TRANSFER_REQUEST_NOT_APPROVED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Approves and performs a transferFrom on the bound ERC-20 token, using this rule as spender.
     * @dev Requires `from` to have approved this contract on the token.
     * @dev This function is only safe for tokens that call back `transferred()` during transfer.
     * @dev CEI is intentionally inverted so the approval exists for the callback.
     * @dev Works in BOTH topologies, provided the bindings are set correctly:
     *      - direct binding: `bindToken(token)` — the token calls back `transferred` itself;
     *      - RuleEngine:     `bindToken(token)` AND `bindRuleEngine(engine)` — the engine calls back.
     *      The token must be bound with {bindToken}; binding the RuleEngine there instead would make
     *      `getTokenBound()` a non-ERC-20 and this call would revert.
     * @param from The holder to transfer tokens from.
     * @param to The recipient of the transfer.
     * @param value The amount to transfer.
     * @return True when the transfer succeeds.
     */
    function approveAndTransferIfAllowed(address from, address to, uint256 value)
        public
        virtual
        onlyTransferApprover
        returns (bool)
    {
        address token = getTokenBound();
        require(token != address(0), RuleConditionalTransferLight_TokenNotBound());

        uint256 approvalsBefore = approvedCount(from, to, value);
        approveTransfer(from, to, value);

        uint256 allowed = IERC20(token).allowance(from, address(this));
        require(allowed >= value, RuleConditionalTransferLight_InsufficientAllowance(token, from, allowed, value));

        IERC20(token).safeTransferFrom(from, to, value);

        // The approval above exists ONLY for the token's compliance callback to consume. If the count
        // did not come back down, no callback reached this rule -- the binding is wrong -- and leaving
        // the surplus would authorise a later, never-approved transfer of the same tuple. Read after
        // the external call deliberately: a hostile token can make this fail, never pass spuriously.
        require(
            approvedCount(from, to, value) == approvalsBefore,
            RuleConditionalTransferLight_ApprovalNotConsumed(token, from, to, value)
        );
        return true;
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value)
        public
        virtual
        override(IERC3643IComplianceContract)
        onlyTransferExecutor
    {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRuleEngine
     */
    function transferred(
        address,
        /* spender */
        address from,
        address to,
        uint256 value
    )
        public
        virtual
        override(IRuleEngine)
        onlyTransferExecutor
    {
        _transferred(from, to, value);
    }

    /**
     * @notice Binds the ERC-20 token this rule acts on. Reverts if a token is already bound.
     * @dev Only ONE token may be bound at a time. To migrate to a new token, call `unbindToken` first.
     * @dev The bound token is BOTH the ERC-20 that {approveAndTransferIfAllowed} transfers, AND an
     *      authorized caller of `transferred` (the direct-binding topology). If the rule sits behind
     *      a RuleEngine, additionally call {bindRuleEngine} so the engine may call `transferred` too.
     * @dev WARNING: Single-token binding alone does NOT guarantee token-scoped approvals: this rule's
     *      approvals are keyed `(from, to, value)` with no token dimension. A multi-tenant
     *      {bindRuleEngine} target would relay several tokens into the same approval bucket — see
     *      the warning on {bindRuleEngine}.
     * @dev WARNING: `unbindToken` does not clear `approvalCounts`, and does not clear the bound
     *      {ruleEngine} either. Stale approvals from the previous token remain in storage and can be
     *      consumed after rebinding — and the previously bound engine stays authorized to consume
     *      them until {unbindRuleEngine} is called. The operator who controls rebinding also controls
     *      approvals, so the trust model is preserved, but integrators should be aware of this
     *      behavior. When migrating, call {resetApproval} for each affected transfer AND
     *      {unbindRuleEngine} before rebinding.
     * @param token The ERC-20 token to bind to this rule.
     */
    function bindToken(address token)
        public
        virtual
        override(ITokenBinding, TokenBindingModule)
        onlyTokenBindingManager
    {
        require(getTokenBound() == address(0), RuleConditionalTransferLight_TokenAlreadyBound());
        _bindToken(token);
    }

    /**
     * @notice Authorizes a RuleEngine to call this rule's transfer execution hooks.
     * @dev Independent of {bindToken}: the engine may call `transferred` but is never treated as the
     *      ERC-20 token. Bind both and {approveAndTransferIfAllowed} works under the engine topology.
     *      Reverts if an engine is already bound; call {unbindRuleEngine} first to migrate.
     *
     * @dev WARNING: **bind ONLY an engine that serves this one token.** Approvals here are keyed
     *      `(from, to, value)` with **no token dimension**, while a `RuleEngine` is multi-tenant by
     *      design and relays every one of its tokens into the same hook. If the engine serves several
     *      tokens, an approval recorded for one is consumable by ANY of them -- approve 100 for token
     *      A, and a 100 transfer of token B consumes it. That is inherent to the single-token rule and
     *      is why {RuleConditionalTransferLightMultiToken} exists; binding an engine does not change
     *      it. If the engine is or may become multi-tenant, do not use this rule.
     * @param ruleEngine_ The RuleEngine allowed to call `transferred`. It MUST serve only the token
     *                    bound via {bindToken}.
     */
    function bindRuleEngine(address ruleEngine_) public virtual onlyTokenBindingManager {
        require(ruleEngine_ != address(0), RuleConditionalTransferLight_RuleEngineAddressZeroNotAllowed());
        require(ruleEngine == address(0), RuleConditionalTransferLight_RuleEngineAlreadyBound());
        ruleEngine = ruleEngine_;
        emit RuleEngineBound(ruleEngine_);
    }

    /**
     * @notice Revokes the bound RuleEngine's authorization to call the transfer execution hooks.
     * @dev Does NOT clear `approvalCounts` — see the {bindToken} warning and {resetApproval}.
     */
    function unbindRuleEngine() public virtual onlyTokenBindingManager {
        address previous = ruleEngine;
        require(previous != address(0), RuleConditionalTransferLight_RuleEngineNotBound());
        ruleEngine = address(0);
        emit RuleEngineUnbound(previous);
    }

    /**
     * @notice Returns whether `caller` is authorized to call this rule's transfer execution hooks.
     * @param caller The address to check.
     * @return True if `caller` is the bound token or the bound RuleEngine.
     */
    function isTransferExecutor(address caller) public view virtual returns (bool) {
        return isTokenBound(caller) || (caller != address(0) && caller == ruleEngine);
    }

    /**
     * @inheritdoc IERC1404
     */
    function detectTransferRestriction(address from, address to, uint256 value)
        public
        view
        override(IERC1404)
        returns (uint8)
    {
        if (from == address(0) || to == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
        bytes32 transferHash = _transferHash(from, to, value);
        if (approvalCounts[transferHash] == 0) {
            return CODE_TRANSFER_REQUEST_NOT_APPROVED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC1404Extend
     */
    function detectTransferRestrictionFrom(
        address,
        /* spender */
        address from,
        address to,
        uint256 value
    )
        public
        view
        override(IERC1404Extend)
        returns (uint8)
    {
        return detectTransferRestriction(from, to, value);
    }

    /**
     * @inheritdoc IERC3643ComplianceRead
     */
    function canTransfer(address from, address to, uint256 value)
        public
        view
        override(IERC3643ComplianceRead)
        returns (bool)
    {
        return detectTransferRestriction(from, to, value) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC7551Compliance
     */
    function canTransferFrom(address spender, address from, address to, uint256 value)
        public
        view
        override(IERC7551Compliance)
        returns (bool)
    {
        return detectTransferRestrictionFrom(spender, from, to, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorizes transfer execution: the bound token OR the bound RuleEngine may call the
     *         execution hooks. Both topologies are therefore supported without conflating the two
     *         roles of the binding — see {ruleEngine}.
     */
    function _authorizeTransferExecution() internal view virtual override {
        require(
            isTransferExecutor(_msgSender()), RuleConditionalTransferLight_TransferExecutorUnauthorized(_msgSender())
        );
    }
}
