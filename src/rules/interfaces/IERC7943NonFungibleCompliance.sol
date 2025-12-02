// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/**
 * @title IERC7943NonFungibleCompliance
 * @notice Compliance interface for ERC-721/1155–style non-fungible assets.
 * @dev
 *  - For ERC-721 tokens, `amount` MUST be set to `1`.
 *  - This interface defines a read-only compliance check used to determine
 *    whether a transfer is permitted according to rule-based restrictions.
 */
interface IERC7943NonFungibleCompliance {
    /**
     * @notice Verifies whether a transfer is permitted according to the token’s compliance rules.
     * @dev
     *  This function must not modify state.
     *  It may enforce checks such as:
     *   - Allowlist / blocklist membership
     *   - Freezing rules
     *   - Transfer limitations
     *   - Jurisdictional, regulatory, or policy-driven restrictions
     *  If the transfer is not allowed, this function MUST return `false`.
     *
     * @param from The address currently holding the token.
     * @param to The address intended to receive the token.
     * @param tokenId The ERC-721/1155 token ID being transferred.
     * @param amount The amount being transferred (always `1` for ERC-721).
     * @return allowed `true` if the transfer is permitted, otherwise `false`.
     */
    function canTransfer(address from, address to, uint256 tokenId, uint256 amount)
        external
        view
        returns (bool allowed);
}

/**
 * @title IERC7943NonFungibleComplianceExtend
 * @notice Extended compliance interface for ERC-721/1155–style non-fungible assets.
 * @dev
 *  Adds functionality for:
 *   - Returning standardized transfer-restriction codes
 *   - Compliance checks involving a spender (e.g., approvals and operators)
 *   - Writing compliance-related state upon successful transfers
 *  For ERC-721, `amount/value` MUST be set to `1`.
 */
interface IERC7943NonFungibleComplianceExtend is IERC7943NonFungibleCompliance {
    /**
     * @notice Returns a transfer-restriction code describing why a transfer is blocked.
     * @dev
     *  - MUST NOT modify state.
     *  - MUST return `0` when the transfer is allowed.
     *  - Non-zero codes SHOULD follow the ERC-1404 or RuleEngine restriction-code conventions.
     *
     * @param from The address currently holding the token.
     * @param to The address intended to receive the token.
     * @param tokenId The ERC-721/1155 token ID being checked.
     * @param amount The amount being transferred (always `1` for ERC-721).
     * @return code A restriction code: `0` for success, otherwise an implementation-defined error code.
     */
    function detectTransferRestriction(address from, address to, uint256 tokenId, uint256 amount)
        external
        view
        returns (uint8 code);

    /**
     * @notice Returns a transfer-restriction code for transfers triggered by a spender.
     * @dev
     *  Similar to `detectTransferRestriction`, but includes the spender performing the transfer.
     *  - MUST NOT modify state.
     *  - MUST return `0` when transfer is allowed.
     *
     * @param spender The caller executing the transfer (owner, operator, or approved address).
     * @param from The current owner of the token.
     * @param to The intended recipient.
     * @param tokenId The token ID being checked.
     * @param value The amount being transferred (always `1` for ERC-721).
     * @return code A restriction code: `0` for allowed, otherwise a non-zero restriction identifier.
     */
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 tokenId, uint256 value)
        external
        view
        returns (uint8 code);

    /**
     * @notice Determines whether a spender-initiated transfer is allowed.
     * @dev
     *  - MUST NOT modify state.
     *  - Implementations SHOULD use `detectTransferRestrictionFrom` internally.
     *
     * @param spender The address performing the transfer (owner/operator).
     * @param from The current token owner.
     * @param to The recipient address.
     * @param tokenId The token ID being transferred.
     * @param value The transfer amount (always `1` for ERC-721).
     * @return allowed `true` if the transfer is permitted, otherwise `false`.
     */
    function canTransferFrom(address spender, address from, address to, uint256 tokenId, uint256 value)
        external
        returns (bool allowed);

    /**
     * @notice Notifies the rule engine or compliance module that a transfer has been executed.
     * @dev
     *  - MAY modify compliance-related state (e.g., consumption of approvals, updating limits).
     *  - MUST be called by the token contract after a successful transfer.
     *  - MUST revert if called by unauthorized contracts.
     *
     * @param spender The address executing the transfer.
     * @param from The previous owner of the token.
     * @param to The new owner of the token.
     * @param tokenId The token ID that was transferred.
     * @param value The transfer amount (always `1` for ERC-721).
     */
    function transferred(address spender, address from, address to, uint256 tokenId, uint256 value) external;
}
