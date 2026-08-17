// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {
    IERC7943NonFungibleCompliance,
    IERC7943NonFungibleComplianceExtend
} from "../../../interfaces/IERC7943NonFungibleCompliance.sol";
import {RuleTransferValidation} from "./RuleTransferValidation.sol";
import {ITransferContext} from "../../../interfaces/ITransferContext.sol";

/**
 * @title Rule NFT Adapter
 * @notice Provides ERC-7943 overloads for rules that already implement core transfer checks.
 * @dev Delegates tokenId overloads to RuleTransferValidation's internal hooks.
 *
 * @dev **The interfaces here signal "direct transfer" differently, and {_isDelegated} is where that is
 * reconciled.** ERC-7943 documents its `spender` as "the address performing the transfer
 * (owner/operator)" and {ITransferContext} documents `sender` as the token's `msg.sender`, so on BOTH
 * an owner moving their own tokens arrives as `spender == from`. The CMTAT 3-arg/4-arg pair instead
 * signals it with `spender == address(0)` and the 3-arg overload. Every entrypoint on this adapter
 * therefore normalises `spender == from` to the direct hook; the 4-arg CMTAT path deliberately does
 * NOT, because its own convention already distinguishes the two. Do not "align" them: an owner-
 * initiated ERC-721 `transferFrom` would then be screened as a delegated transfer, which
 * {RuleSpenderWhitelistBase} documents as always allowed.
 */
abstract contract RuleNFTAdapter is RuleTransferValidation, IERC7943NonFungibleComplianceExtend, ITransferContext {
    /**
     * @notice Selector of the ERC-3643 compliance `transferred` hook.
     */
    bytes4 internal constant TRANSFERRED_SELECTOR_ERC3643 = IERC3643IComplianceContract.transferred.selector;
    /**
     * @notice Selector of the RuleEngine `transferred` hook.
     */
    bytes4 internal constant TRANSFERRED_SELECTOR_RULE_ENGINE = IRuleEngine.transferred.selector;
    /**
     * @notice Selector of the ERC-7943 `transferred(from,to,tokenId,value)` hook.
     */
    bytes4 internal constant TRANSFERRED_SELECTOR_ERC7943 =
        bytes4(keccak256("transferred(address,address,uint256,uint256)"));
    /**
     * @notice Selector of the ERC-7943 `transferred(spender,from,to,tokenId,value)` hook.
     */
    bytes4 internal constant TRANSFERRED_SELECTOR_ERC7943_FROM =
        bytes4(keccak256("transferred(address,address,address,uint256,uint256)"));

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ITransferContext
     */
    function transferred(MultiTokenTransferContext calldata ctx) external virtual override {
        if (_isDelegated(ctx.sender, ctx.from)) {
            _transferredFrom(ctx.sender, ctx.from, ctx.to, ctx.value);
        } else {
            _transferred(ctx.from, ctx.to, ctx.value);
        }
    }

    /**
     * @inheritdoc ITransferContext
     */
    function transferred(FungibleTransferContext calldata ctx) external virtual override {
        if (_isDelegated(ctx.sender, ctx.from)) {
            _transferredFrom(ctx.sender, ctx.from, ctx.to, ctx.value);
        } else {
            _transferred(ctx.from, ctx.to, ctx.value);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function transferred(
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        virtual
        override(IERC7943NonFungibleComplianceExtend)
    {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function transferred(
        address spender,
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        virtual
        override(IERC7943NonFungibleComplianceExtend)
    {
        if (_isDelegated(spender, from)) {
            _transferredFrom(spender, from, to, value);
        } else {
            _transferred(from, to, value);
        }
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function detectTransferRestriction(
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        view
        virtual
        override(IERC7943NonFungibleComplianceExtend)
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function detectTransferRestrictionFrom(
        address spender,
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        view
        virtual
        override(IERC7943NonFungibleComplianceExtend)
        returns (uint8)
    {
        return _isDelegated(spender, from)
            ? _detectTransferRestrictionFrom(spender, from, to, value)
            : _detectTransferRestriction(from, to, value);
    }

    /**
     * @inheritdoc IERC7943NonFungibleCompliance
     */
    function canTransfer(
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 amount
    )
        public
        view
        virtual
        override(IERC7943NonFungibleCompliance)
        returns (bool)
    {
        return _detectTransferRestriction(from, to, amount) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function canTransferFrom(
        address spender,
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        view
        virtual
        override(IERC7943NonFungibleComplianceExtend)
        returns (bool)
    {
        return detectTransferRestrictionFrom(spender, from, to, 0, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether `spender` acts on behalf of `from`, rather than being `from` itself.
     * @dev The whole adapter routes on this. `spender == from` is an owner-initiated transfer and takes
     * the direct hook, matching what a plain `transfer` produces on the CMTAT path (`spender == 0`,
     * 3-arg overload). Nethermind AuditAgent NM-6: the ERC-7943 overloads used to call the
     * spender-aware hook unconditionally, so an owner-initiated ERC-721 `transferFrom` was screened as
     * delegated while the identical {ITransferContext} call was not.
     * @param spender Address performing the transfer, as reported by the calling interface.
     * @param from Address the tokens leave.
     * @return True when the transfer is delegated and the spender must be screened.
     */
    function _isDelegated(address spender, address from) internal pure virtual returns (bool) {
        return spender != address(0) && spender != from;
    }

    /**
     * @notice Internal hook for post-transfer validation or state updates.
     * @param from Address tokens are transferred from.
     * @param to Address tokens are transferred to.
     * @param value Amount transferred.
     */
    function _transferred(address from, address to, uint256 value) internal virtual;

    /**
     * @notice Internal hook for post-transfer validation or state updates (spender-aware).
     * @param spender Address executing the transfer on behalf of `from`.
     * @param from Address tokens are transferred from.
     * @param to Address tokens are transferred to.
     * @param value Amount transferred.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal virtual;
}
