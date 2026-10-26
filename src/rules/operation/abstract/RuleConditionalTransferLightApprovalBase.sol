// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {ITransferContext} from "../../interfaces/ITransferContext.sol";
import {RuleConditionalTransferLightInvariantStorage} from "./RuleConditionalTransferLightInvariantStorage.sol";

/**
 * @title RuleConditionalTransferLightApprovalBase
 * @dev Pure approval state machine: stores and consumes per-transfer approvals.
 *      No knowledge of token binding or compliance interfaces.
 */
abstract contract RuleConditionalTransferLightApprovalBase is RuleConditionalTransferLightInvariantStorage {
    /**
     * @notice Number of outstanding approvals for each transfer hash (mapping from transfer hash to approval count)
     */
    mapping(bytes32 => uint256) public approvalCounts;

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyTransferApprover() {
        _authorizeTransferApproval();
        _;
    }

    modifier onlyTransferExecutor() {
        _authorizeTransferExecution();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Consumes one approval for the transfer described by `ctx`.
     * @param ctx The fungible transfer context (from, to, value).
     */
    function transferred(ITransferContext.FungibleTransferContext calldata ctx) external onlyTransferExecutor {
        _transferredFromContext(ctx);
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Records a new approval for the given transfer, incrementing its approval count.
     * @param from The sender of the transfer to approve.
     * @param to The recipient of the transfer to approve.
     * @param value The amount of the transfer to approve.
     */
    function approveTransfer(address from, address to, uint256 value) public virtual onlyTransferApprover {
        bytes32 transferHash = _transferHash(from, to, value);
        uint256 newCount = approvalCounts[transferHash] + 1;
        approvalCounts[transferHash] = newCount;
        emit TransferApproved(from, to, value, newCount);
    }

    /**
     * @notice Cancels one outstanding approval for the given transfer; reverts if none exists.
     * @param from The sender of the transfer whose approval is cancelled.
     * @param to The recipient of the transfer whose approval is cancelled.
     * @param value The amount of the transfer whose approval is cancelled.
     */
    function cancelTransferApproval(address from, address to, uint256 value) public virtual onlyTransferApprover {
        bytes32 transferHash = _transferHash(from, to, value);
        uint256 count = approvalCounts[transferHash];
        require(count != 0, TransferApprovalNotFound());
        approvalCounts[transferHash] = count - 1;
        emit TransferApprovalCancelled(from, to, value, approvalCounts[transferHash]);
    }

    /**
     * @notice Discards every outstanding approval for the given transfer in one call.
     * @dev
     * - Reverts if no approval exists, per the single-item convention (use {cancelTransferApproval}
     *   to remove exactly one).
     * - Deliberately does NOT require a bound token: the primary use is cleaning up approvals that
     *   survived an {unbindToken}, at which point no token is bound. See the {bindToken} warning.
     * @param from The sender of the transfer whose approvals are cleared.
     * @param to The recipient of the transfer whose approvals are cleared.
     * @param value The amount of the transfer whose approvals are cleared.
     * @return cleared The approval count that was discarded.
     */
    function resetApproval(address from, address to, uint256 value)
        public
        virtual
        onlyTransferApprover
        returns (uint256 cleared)
    {
        bytes32 transferHash = _transferHash(from, to, value);
        cleared = approvalCounts[transferHash];
        require(cleared != 0, TransferApprovalNotFound());
        approvalCounts[transferHash] = 0;
        emit TransferApprovalReset(from, to, value, cleared);
    }

    /**
     * @notice Returns the number of outstanding approvals for the given transfer.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     * @return The current approval count for the transfer.
     */
    function approvedCount(address from, address to, uint256 value) public view returns (uint256) {
        bytes32 transferHash = _transferHash(from, to, value);
        return approvalCounts[transferHash];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Consumes one approval for the transfer described by `ctx`.
     * @param ctx The fungible transfer context (from, to, value).
     */
    function _transferredFromContext(ITransferContext.FungibleTransferContext calldata ctx) internal virtual {
        _transferred(ctx.from, ctx.to, ctx.value);
    }

    /**
     * @notice Consumes one approval for the given transfer; reverts if none exists.
     * @dev No-op when either endpoint is the zero address (mint/burn).
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     */
    function _transferred(address from, address to, uint256 value) internal virtual {
        if (from == address(0) || to == address(0)) {
            return;
        }
        bytes32 transferHash = _transferHash(from, to, value);
        uint256 count = approvalCounts[transferHash];

        require(count != 0, TransferNotApproved());

        approvalCounts[transferHash] = count - 1;
        emit TransferExecuted(from, to, value, approvalCounts[transferHash]);
    }

    /**
     * @notice Computes the storage key identifying a (from, to, value) transfer.
     * @dev The preimage is project-specific: **96 bytes, three words, each address LEFT-aligned and
     * right-padded with 12 zero bytes** (`from || to || value`).
     * WARNING: this is NEITHER `abi.encodePacked` (72 bytes, no padding) NOR `abi.encode` (96 bytes,
     * addresses RIGHT-aligned). Reimplementing it off-chain as either yields a different hash, and
     * because the result is a mapping key the mistake is **silent** -- the lookup returns 0, which is
     * indistinguishable from "no approval exists". Either of these reproduces it:
     * ```solidity
     * keccak256(abi.encodePacked(from, bytes12(0), to, bytes12(0), value))
     * keccak256(abi.encode(bytes32(bytes20(from)), bytes32(bytes20(to)), value))
     * ```
     * Pinned by `testDocumentedPreimageMatchesTheStorageKey`. Use {approvedCount} unless you need
     * the storage slot directly.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount of the transfer.
     * @return hash The keccak256 hash uniquely identifying the transfer.
     */
    function _transferHash(address from, address to, uint256 value) internal pure virtual returns (bytes32 hash) {
        // Hand-rolled rather than `abi.encodePacked` on the linter's `asm-keccak256` advice: this is
        // on the transfer write path, and the assembly is ~109 gas cheaper per call. Injectivity is
        // verified in `CLAUDE_AUDIT.md` F-12; the exact layout is documented above.
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, shl(96, from))
            mstore(add(ptr, 0x20), shl(96, to))
            mstore(add(ptr, 0x40), value)
            hash := keccak256(ptr, 0x60)
        }
    }

    /**
     * @notice Authorizes the caller to approve or cancel transfers; reverts if unauthorized.
     */
    function _authorizeTransferApproval() internal view virtual;

    /**
     * @notice Authorizes the caller to execute (consume) approved transfers; reverts if unauthorized.
     */
    function _authorizeTransferExecution() internal view virtual;
}
