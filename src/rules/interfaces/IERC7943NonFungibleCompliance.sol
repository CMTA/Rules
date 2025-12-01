// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/**
* @dev for ERC-721 amount = 1
 */
interface IERC7943NonFungibleCompliance {
    /// @notice Checks if a transfer is currently possible according to token rules. It enforces validations on the frozen tokens.
    /// @dev This may involve checks like allowlists, blocklists, transfer limits and other policy-defined restrictions.
    /// @param from The address sending tokens.
    /// @param to The address receiving tokens. 
    /// @param tokenId The ID of the token being transferred.
    /// @param amount The amount being transferred.
    /// @return allowed True if the transfer is allowed, false otherwise.
    function canTransfer(address from, address to, uint256 tokenId, uint256 amount) external view returns (bool allowed);
}

/**
* @dev for ERC-721 amount = 1
 */
interface IERC7943NonFungibleComplianceExtend is IERC7943NonFungibleCompliance {
    function detectTransferRestriction(address from, address to, uint256 tokenId, uint256  amount ) external view returns(uint8 code);
    
}
 