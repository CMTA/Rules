// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title ITransferContext — transfer context structs and post-transfer hooks.
 */
interface ITransferContext {
    /**
     * @notice Transfer context for unified rule entrypoints.
     * @dev Inspired by the TokenF contract: https://github.com/dl-tokenf/contracts
     * @param selector Function selector of the original call.
     * @param sender Address that initiated the transfer (msg.sender in the token contract).
     * @param from Token sender.
     * @param to Token recipient.
     * @param value Amount transferred (fungible).
     * @param tokenId Token id (non-fungible).
     * @param data Optional extra data provided by the token for rule evaluation.
     */
    struct MultiTokenTransferContext {
        bytes4 selector;
        address sender;
        address from;
        address to;
        uint256 value;
        uint256 tokenId;
        bytes data;
    }

    /**
     * @notice Transfer context for fungible transfers.
     * @param selector Function selector of the original call.
     * @param sender Address that initiated the transfer (msg.sender in the token contract).
     * @param from Token sender.
     * @param to Token recipient.
     * @param value Amount transferred.
     * @param data Optional extra data provided by the token for rule evaluation.
     */
    struct FungibleTransferContext {
        bytes4 selector;
        address sender;
        address from;
        address to;
        uint256 value;
        bytes data;
    }

    /**
     * @notice Notifies the rule of an executed multi-token transfer.
     * @param ctx The multi-token transfer context describing the transfer.
     */
    function transferred(MultiTokenTransferContext calldata ctx) external;

    /**
     * @notice Notifies the rule of an executed fungible transfer.
     * @param ctx The fungible transfer context describing the transfer.
     */
    function transferred(FungibleTransferContext calldata ctx) external;
}
