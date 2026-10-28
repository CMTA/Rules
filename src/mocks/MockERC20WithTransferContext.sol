// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ITransferContext} from "../rules/interfaces/ITransferContext.sol";

/**
 * @title MockERC20WithTransferContext — ERC20 mock that notifies a transfer-context rule
 * @notice Test double that forwards fungible/multi-token transfer context to a
 *         configured ITransferContext rule after each transfer.
 */
contract MockERC20WithTransferContext is ERC20 {
    /**
     * @notice The transfer-context rule notified on each transfer.
     */
    ITransferContext public rule;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the mock ERC20 token.
     * @param name_ The token name.
     * @param symbol_ The token symbol.
     */
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

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
     * @notice Mints tokens to an address.
     * @param to The recipient of the minted tokens.
     * @param value The amount to mint.
     */
    function mint(address to, uint256 value) external {
        _mint(to, value);
    }

    /**
     * @notice Transfers tokens from the caller and notifies the rule with the chosen context.
     * @param to The recipient of the transfer.
     * @param value The amount to transfer.
     * @param useFungibleContext If true, notify with a fungible context; otherwise a multi-token context.
     * @param tokenId The token id used when notifying with a multi-token context.
     * @return Always true on success.
     */
    function transferWithContext(address to, uint256 value, bool useFungibleContext, uint256 tokenId)
        external
        returns (bool)
    {
        _transfer(_msgSender(), to, value);
        if (useFungibleContext) {
            _notifyFungible(_msgSender(), _msgSender(), to, value);
        } else {
            _notifyMultiToken(_msgSender(), _msgSender(), to, value, tokenId);
        }
        return true;
    }

    /**
     * @notice Transfers tokens via allowance and notifies the rule with the chosen context.
     * @param from The address tokens are transferred from.
     * @param to The recipient of the transfer.
     * @param value The amount to transfer.
     * @param useFungibleContext If true, notify with a fungible context; otherwise a multi-token context.
     * @param tokenId The token id used when notifying with a multi-token context.
     * @return Always true on success.
     */
    function transferFromWithContext(address from, address to, uint256 value, bool useFungibleContext, uint256 tokenId)
        external
        returns (bool)
    {
        address sender = _msgSender();
        _spendAllowance(from, sender, value);
        _transfer(from, to, value);

        if (useFungibleContext) {
            _notifyFungible(sender, from, to, value);
        } else {
            _notifyMultiToken(sender, from, to, value, tokenId);
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ERC20
     */
    function transfer(address to, uint256 value) public virtual override returns (bool) {
        bool success = super.transfer(to, value);
        _notifyFungible(_msgSender(), _msgSender(), to, value);
        return success;
    }

    /**
     * @inheritdoc ERC20
     */
    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address sender = _msgSender();
        bool success = super.transferFrom(from, to, value);
        _notifyFungible(sender, from, to, value);
        return success;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Builds a fungible transfer context and forwards it to the configured rule.
     * @dev No-op when no rule is set.
     * @param sender The message sender that initiated the transfer.
     * @param from The address tokens were transferred from.
     * @param to The address tokens were transferred to.
     * @param value The amount transferred.
     */
    function _notifyFungible(address sender, address from, address to, uint256 value) internal {
        if (address(rule) == address(0)) {
            return;
        }

        ITransferContext.FungibleTransferContext memory ctx = ITransferContext.FungibleTransferContext({
            selector: sender == from ? this.transfer.selector : this.transferFrom.selector,
            sender: sender,
            from: from,
            to: to,
            value: value,
            data: ""
        });
        rule.transferred(ctx);
    }

    /**
     * @notice Builds a multi-token transfer context and forwards it to the configured rule.
     * @dev No-op when no rule is set.
     * @param sender The message sender that initiated the transfer.
     * @param from The address tokens were transferred from.
     * @param to The address tokens were transferred to.
     * @param value The amount transferred.
     * @param tokenId The token id associated with the transfer.
     */
    function _notifyMultiToken(address sender, address from, address to, uint256 value, uint256 tokenId) internal {
        if (address(rule) == address(0)) {
            return;
        }

        ITransferContext.MultiTokenTransferContext memory ctx = ITransferContext.MultiTokenTransferContext({
            selector: sender == from ? this.transfer.selector : this.transferFrom.selector,
            sender: sender,
            from: from,
            to: to,
            value: value,
            tokenId: tokenId,
            data: ""
        });
        rule.transferred(ctx);
    }
}
