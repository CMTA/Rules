// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643ComplianceRead, IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {ERC3643ComplianceModule} from "RuleEngine/modules/ERC3643ComplianceModule.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VersionModule} from "../../../modules/VersionModule.sol";
import {
    RuleConditionalTransferLightMultiTokenInvariantStorage
} from "./RuleConditionalTransferLightMultiTokenInvariantStorage.sol";
import {ITransferContext} from "../../interfaces/ITransferContext.sol";

/**
 * @title RuleConditionalTransferLightMultiTokenBase — conditional-transfer rule wiring per-token approval state into the compliance interfaces
 */
abstract contract RuleConditionalTransferLightMultiTokenBase is
    VersionModule,
    ERC3643ComplianceModule,
    RuleConditionalTransferLightMultiTokenInvariantStorage,
    IRule
{
    using SafeERC20 for IERC20;

    /**
     * @notice Number of outstanding approvals for each per-token transfer hash
     */
    mapping(bytes32 => uint256) public approvalCounts;

    modifier onlyTransferApprover() {
        _authorizeTransferApproval();
        _;
    }

    modifier onlyTransferExecutor() {
        _authorizeTransferExecution();
        _;
    }

    /**
     * @notice Compliance hook invoked when tokens are created (minted); consumes an approval if applicable.
     * @param to The recipient of the created tokens.
     * @param value The amount of tokens created.
     */
    function created(address to, uint256 value) external onlyBoundToken {
        _transferred(_msgSender(), address(0), to, value);
    }

    /**
     * @notice Compliance hook invoked when tokens are destroyed (burned); consumes an approval if applicable.
     * @param from The holder whose tokens are destroyed.
     * @param value The amount of tokens destroyed.
     */
    function destroyed(address from, uint256 value) external onlyBoundToken {
        _transferred(_msgSender(), from, address(0), value);
    }

    /**
     * @notice Consumes one approval for the transfer described by `ctx`, using the caller as the token.
     * @param ctx The fungible transfer context (from, to, value).
     */
    function transferred(ITransferContext.FungibleTransferContext calldata ctx) external onlyTransferExecutor {
        _transferred(_msgSender(), ctx.from, ctx.to, ctx.value);
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

    /**
     * @notice Records a new approval for the given per-token transfer.
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer to approve.
     * @param to The recipient of the transfer to approve.
     * @param value The amount of the transfer to approve.
     */
    function approveTransfer(address token, address from, address to, uint256 value)
        public
        virtual
        onlyTransferApprover
    {
        _approveTransfer(token, from, to, value);
    }

    /**
     * @notice Cancels one outstanding approval for the given per-token transfer.
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer whose approval is cancelled.
     * @param to The recipient of the transfer whose approval is cancelled.
     * @param value The amount of the transfer whose approval is cancelled.
     */
    function cancelTransferApproval(address token, address from, address to, uint256 value)
        public
        virtual
        onlyTransferApprover
    {
        _cancelTransferApproval(token, from, to, value);
    }

    /**
     * @notice Approves and performs a transferFrom of `token` using this rule as spender.
     * @dev Requires `from` to have approved this contract on `token`; the token must be bound.
     * @param token The token to transfer.
     * @param from The holder to transfer tokens from.
     * @param to The recipient of the transfer.
     * @param value The amount to transfer.
     * @return True when the transfer succeeds.
     */
    function approveAndTransferIfAllowed(address token, address from, address to, uint256 value)
        public
        virtual
        onlyTransferApprover
        returns (bool)
    {
        require(isTokenBound(token), RuleConditionalTransferLightMultiToken_InvalidToken());

        uint256 approvalsBefore = approvedCount(token, from, to, value);
        _approveTransfer(token, from, to, value);

        uint256 allowed = IERC20(token).allowance(from, address(this));
        require(
            allowed >= value, RuleConditionalTransferLightMultiToken_InsufficientAllowance(token, from, allowed, value)
        );

        IERC20(token).safeTransferFrom(from, to, value);

        // See the single-token twin: the approval exists only for the token's compliance callback, so
        // a count that did not come back down means no callback reached this rule and the surplus
        // would otherwise stay spendable.
        require(
            approvedCount(token, from, to, value) == approvalsBefore,
            RuleConditionalTransferLightMultiToken_ApprovalNotConsumed(token, from, to, value)
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
        _transferred(_msgSender(), from, to, value);
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
        _transferred(_msgSender(), from, to, value);
    }

    /**
     * @notice Discards every outstanding approval for the given per-token transfer in one call.
     * @dev
     * - Reverts if no approval exists, per the single-item convention (use {cancelTransferApproval}
     *   to remove exactly one).
     * - Deliberately does NOT require the token to be bound, unlike {approveTransfer}: the primary
     *   use is cleaning up approvals that survived an {unbindToken}, at which point the token is by
     *   definition no longer bound. It is also the only way to clear approvals stranded under a key
     *   that can never be consumed (see `CLAUDE_AUDIT.md` finding F-4).
     * @param token The token whose approvals are cleared.
     * @param from The sender of the transfer whose approvals are cleared.
     * @param to The recipient of the transfer whose approvals are cleared.
     * @param value The amount of the transfer whose approvals are cleared.
     * @return cleared The approval count that was discarded.
     */
    function resetApproval(address token, address from, address to, uint256 value)
        public
        virtual
        onlyTransferApprover
        returns (uint256 cleared)
    {
        bytes32 transferHash = _transferHash(token, from, to, value);
        cleared = approvalCounts[transferHash];
        require(cleared != 0, RuleConditionalTransferLightMultiToken_TransferApprovalNotFound());
        approvalCounts[transferHash] = 0;
        emit TransferApprovalReset(token, from, to, value, cleared);
    }

    /**
     * @notice Returns the number of outstanding approvals for the given per-token transfer.
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     * @return The current approval count for the transfer.
     */
    function approvedCount(address token, address from, address to, uint256 value) public view returns (uint256) {
        bytes32 transferHash = _transferHash(token, from, to, value);
        return approvalCounts[transferHash];
    }

    /**
     * @inheritdoc IERC1404
     * @dev CALLER-DEPENDENT. The token key is derived from `msg.sender`, so this view only returns a
     *      meaningful answer when it is invoked BY the bound token. Any other caller — an off-chain
     *      `eth_call` from a wallet, an explorer, an aggregator — always receives
     *      `CODE_TRANSFER_REQUEST_NOT_APPROVED`, even for a transfer that is approved and will succeed.
     *      It is fail-closed, but it carries no signal for third-party pre-flight.
     *      Use {detectTransferRestrictionForToken} instead, which takes the token explicitly.
     */
    function detectTransferRestriction(address from, address to, uint256 value)
        public
        view
        override(IERC1404)
        returns (uint8)
    {
        return _detectTransferRestrictionForToken(_msgSender(), from, to, value);
    }

    /**
     * @notice Caller-explicit pre-flight: returns the restriction code for a transfer of `token`.
     * @dev Unlike {detectTransferRestriction}, the token is passed in rather than derived from
     *      `msg.sender`, so any caller (notably an off-chain `eth_call`) gets the real answer.
     *      This is the view integrators should use.
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     * @return The restriction code, or TRANSFER_OK when an approval exists.
     */
    function detectTransferRestrictionForToken(address token, address from, address to, uint256 value)
        public
        view
        virtual
        returns (uint8)
    {
        return _detectTransferRestrictionForToken(token, from, to, value);
    }

    /**
     * @notice Caller-explicit pre-flight: whether a transfer of `token` is currently approved.
     * @dev The boolean counterpart of {detectTransferRestrictionForToken}. Prefer this over
     *      {canTransfer}, which is caller-dependent.
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     * @return True when the transfer is approved for `token`.
     */
    function canTransferForToken(address token, address from, address to, uint256 value)
        public
        view
        virtual
        returns (bool)
    {
        return _detectTransferRestrictionForToken(token, from, to, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
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
     * @dev CALLER-DEPENDENT, for the same reason as {detectTransferRestriction}: a caller that is not
     *      the bound token always reads `false`. Use {canTransferForToken} for an off-chain pre-flight.
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

    /**
     * @notice Authorizes changes to compliance binding: restricted to the compliance manager.
     * @dev NOT `view`, unlike every other access-control hook in this codebase. This is structural,
     *      not an oversight: the implementation delegates to `_onlyComplianceManager()`, which
     *      `lib/RuleEngine`'s {ERC3643ComplianceModule} declares as `internal virtual` (non-`view`).
     *      Solidity checks mutability against a virtual's DECLARED type, not the installed override,
     *      so calling it from a `view` function is a compile error — even though every override of it
     *      in this repo is `view`. It can only become `view` once the upstream declaration does.
     *      (The single-token rules avoid this by overriding this hook directly with `onlyRole(...)`
     *      instead of delegating, which is why they are already `view`.)
     */
    function _authorizeComplianceBindingChange(address) internal virtual override {
        _onlyComplianceManager();
    }

    /**
     * @notice Records a new approval for the given per-token transfer; reverts if the token is not bound.
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     */
    function _approveTransfer(address token, address from, address to, uint256 value) internal virtual {
        require(isTokenBound(token), RuleConditionalTransferLightMultiToken_InvalidToken());
        bytes32 transferHash = _transferHash(token, from, to, value);
        uint256 newCount = approvalCounts[transferHash] + 1;
        approvalCounts[transferHash] = newCount;
        emit TransferApproved(token, from, to, value, newCount);
    }

    /**
     * @notice Cancels one outstanding approval for the given per-token transfer; reverts if none exists.
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     */
    function _cancelTransferApproval(address token, address from, address to, uint256 value) internal virtual {
        require(isTokenBound(token), RuleConditionalTransferLightMultiToken_InvalidToken());
        bytes32 transferHash = _transferHash(token, from, to, value);
        uint256 count = approvalCounts[transferHash];

        require(count != 0, RuleConditionalTransferLightMultiToken_TransferApprovalNotFound());

        approvalCounts[transferHash] = count - 1;
        emit TransferApprovalCancelled(token, from, to, value, approvalCounts[transferHash]);
    }

    /**
     * @notice Consumes one approval for the given per-token transfer; reverts if none exists.
     * @dev No-op when either endpoint is the zero address (mint/burn).
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     */
    function _transferred(address token, address from, address to, uint256 value) internal virtual {
        if (from == address(0) || to == address(0)) {
            return;
        }

        bytes32 transferHash = _transferHash(token, from, to, value);
        uint256 count = approvalCounts[transferHash];

        require(count != 0, RuleConditionalTransferLightMultiToken_TransferNotApproved());

        approvalCounts[transferHash] = count - 1;
        emit TransferExecuted(token, from, to, value, approvalCounts[transferHash]);
    }

    /**
     * @notice Computes the restriction code for a transfer of `token`, independently of the caller.
     * @dev Single source of truth for the read path: {detectTransferRestriction} feeds it
     *      `_msgSender()`, while {detectTransferRestrictionForToken} feeds it an explicit token, so
     *      the two can never disagree. Mints and burns are exempt; an unbound token has no
     *      consumable approvals and is therefore always restricted (fail-closed).
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     * @return The restriction code, or TRANSFER_OK when an approval exists.
     */
    function _detectTransferRestrictionForToken(address token, address from, address to, uint256 value)
        internal
        view
        virtual
        returns (uint8)
    {
        if (from == address(0) || to == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }

        if (!isTokenBound(token)) {
            return CODE_TRANSFER_REQUEST_NOT_APPROVED;
        }

        if (approvalCounts[_transferHash(token, from, to, value)] == 0) {
            return CODE_TRANSFER_REQUEST_NOT_APPROVED;
        }

        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Authorizes transfer execution: only a bound token may call the execution hooks.
     */
    function _authorizeTransferExecution() internal view virtual {
        require(
            isTokenBound(_msgSender()),
            RuleConditionalTransferLightMultiToken_TransferExecutorUnauthorized(_msgSender())
        );
    }

    /**
     * @notice Authorizes the caller to approve or cancel transfers; reverts if unauthorized.
     */
    function _authorizeTransferApproval() internal view virtual;

    /**
     * @notice Computes the storage key identifying a (token, from, to, value) transfer.
     * @dev Same project-specific encoding as the single-token rule with `token` prepended: **128
     * bytes, four words, each address LEFT-aligned and right-padded with 12 zero bytes.**
     *
     * WARNING: NEITHER `abi.encodePacked` NOR `abi.encode`. See
     * {RuleConditionalTransferLightApprovalBase._transferHash} for why that matters and for the
     * off-chain formulations that reproduce it. Use {approvedCount} unless you need the storage slot.
     * @param token The token the transfer applies to.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     * @return hash The keccak256 hash uniquely identifying the transfer.
     */
    function _transferHash(address token, address from, address to, uint256 value)
        internal
        pure
        virtual
        returns (bytes32 hash)
    {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, shl(96, token))
            mstore(add(ptr, 0x20), shl(96, from))
            mstore(add(ptr, 0x40), shl(96, to))
            mstore(add(ptr, 0x60), value)
            hash := keccak256(ptr, 0x80)
        }
    }
}
