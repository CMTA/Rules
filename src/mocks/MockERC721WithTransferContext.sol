// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ITransferContext} from "../rules/interfaces/ITransferContext.sol";

/**
 * @title MockERC721WithTransferContext — ERC721 mock that notifies a transfer-context rule
 * @notice Test double that forwards a multi-token transfer context to a configured
 *         ITransferContext rule after each transferFrom.
 */
contract MockERC721WithTransferContext is ERC721 {
    /**
     * @notice The transfer-context rule notified on each transfer.
     */
    ITransferContext public rule;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the mock ERC721 token.
     * @param name_ The token name.
     * @param symbol_ The token symbol.
     */
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the transfer-context rule to notify.
     * @param rule_ The rule address (set to zero to disable notifications).
     */
    function setRule(address rule_) external {
        rule = ITransferContext(rule_);
    }

    /**
     * @notice Mints a token to an address.
     * @param to The recipient of the minted token.
     * @param tokenId The id of the token to mint.
     */
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ERC721
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        address sender = _msgSender();
        super.transferFrom(from, to, tokenId);
        _notifyRule(sender, from, to, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Builds a multi-token transfer context and forwards it to the configured rule.
     * @dev No-op when no rule is set; value is fixed to 1 for a single NFT.
     * @param sender The message sender that initiated the transfer.
     * @param from The address the token was transferred from.
     * @param to The address the token was transferred to.
     * @param tokenId The id of the transferred token.
     */
    function _notifyRule(address sender, address from, address to, uint256 tokenId) internal {
        if (address(rule) == address(0)) {
            return;
        }

        ITransferContext.MultiTokenTransferContext memory ctx = ITransferContext.MultiTokenTransferContext({
            selector: this.transferFrom.selector,
            sender: sender,
            from: from,
            to: to,
            value: 1,
            tokenId: tokenId,
            data: ""
        });
        rule.transferred(ctx);
    }
}
