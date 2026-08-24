// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {BalanceCapManager} from "../core/BalanceCapManager.sol";

/**
 * @title RuleMaxBalanceBase
 * @notice Caps how many tokens a single address may hold, with an operator-managed exemption list.
 * @dev The rule half: constructor, ERC-1404 / ERC-3643 surface, and the mapping from a breached cap
 * to a restriction code; the cap itself lives in {BalanceCapManager}. Screens the **receiver** --
 * rejected when `balanceOf(to) + value > maxBalance`, mints included. Burns and the sender are not.
 *
 * WARNING: **the cap counts tokens per address, so splitting a position across wallets defeats it.**
 * Pair it with a rule tying addresses to identities (`RuleWhitelist`, `RuleReceiverWhitelist`,
 * `RuleIdentityRegistry`) *and* admit one address per investor.
 *
 * @dev **Assumes the token calls this BEFORE moving the value**, so `balanceOf(to)` still excludes
 * `value`. CMTAT does; a token notifying afterwards would halve the effective cap. Pinned by
 * `testMintExactlyToTheCapProvesPreUpdateAccounting`.
 *
 * @dev `maxBalance = 0` forbids holding entirely; it does not disable the rule. The read path must
 * never revert: an unreadable balance yields {CODE_BALANCE_UNAVAILABLE}
 * (fail-closed). Burns and exempt receivers resolve before any balance is read.
 */
abstract contract RuleMaxBalanceBase is RuleTransferValidation, BalanceCapManager {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule with the observed token and the per-holder cap.
     * @dev Routes through {BalanceCapManager}'s internals, which are constructor-agnostic, so the
     * initial configuration is announced by {MaxBalanceTokenUpdated} and {MaxBalanceUpdated} exactly
     * like every later change. An upgradeable variant would call the same two from an initializer.
     * @param balanceToken_ Token whose `balanceOf` is checked; must be a contract.
     * @param maxBalance_ Maximum balance per non-exempt address. `0` forbids holding entirely.
     */
    constructor(address balanceToken_, uint256 maxBalance_) {
        _setBalanceToken(balanceToken_);
        _setMaxBalance(maxBalance_);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this rule can produce the given restriction code.
     * @param restrictionCode Restriction code to test.
     * @return True if `restrictionCode` is one of this rule's codes.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_MAX_BALANCE_EXCEEDED || restrictionCode == CODE_BALANCE_UNAVAILABLE;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the balance `to` may still receive before reaching the cap.
     * @dev Mirrors what {_detectTransferRestriction} computes, so an integrator can size a transfer
     * without simulating it. Never reverts. This is the ERC-1404-flavoured wrapper over
     * {BalanceCapManager._remainingCapacity}: the manager answers in booleans, the rule maps that to
     * a restriction code.
     * @param to The prospective receiver.
     * @return restrictionCode `0` when the headroom is meaningful, otherwise the code a transfer
     * would return.
     * @return headroom Remaining capacity in token units. `type(uint256).max` for an exempt address
     * or the burn sentinel; meaningless when `restrictionCode` is non-zero.
     */
    function remainingCapacity(address to) public view virtual returns (uint8 restrictionCode, uint256 headroom) {
        (bool balanceAvailable, uint256 headroom_) = _remainingCapacity(to);
        if (!balanceAvailable) {
            return (CODE_BALANCE_UNAVAILABLE, 0);
        }
        return (uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK), headroom_);
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value) public view override(IERC3643IComplianceContract) {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRuleEngine
     */
    function transferred(address spender, address from, address to, uint256 value) public view override(IRuleEngine) {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_MAX_BALANCE_EXCEEDED) {
            return TEXT_MAX_BALANCE_EXCEEDED;
        } else if (restrictionCode == CODE_BALANCE_UNAVAILABLE) {
            return TEXT_BALANCE_UNAVAILABLE;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc RuleTransferValidation
     */
    function _detectTransferRestriction(
        address,
        /* from */
        address to,
        uint256 value
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        (bool balanceAvailable, bool exceeded) = _capExceeded(to, value);
        if (!balanceAvailable) {
            return CODE_BALANCE_UNAVAILABLE;
        }
        if (exceeded) {
            return CODE_MAX_BALANCE_EXCEEDED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc RuleTransferValidation
     * @dev The spender is irrelevant: the cap constrains who ends up holding the tokens, not who
     * moved them.
     */
    function _detectTransferRestrictionFrom(address, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @notice Restriction code for the NOTIFICATION phase, i.e. what the write hook enforces.
     * @dev **The seam an ERC-3643 variant overrides.** Defaults to the pre-flight check, correct for a token
     * that notifies BEFORE moving the value (CMTAT). A token that notifies AFTERWARDS reports an observation
     * that already includes `value`, and counting it again halves the effective cap; such a variant overrides
     * this with `_detectTransferRestriction(from, to, 0)`.
     *
     * The read path is deliberately NOT routed through here: a pre-flight view always runs before the movement
     * on either kind of token, so it must always count `value`.
     * @param from Sender address.
     * @param to Recipient address.
     * @param value Amount moved.
     * @return The restriction code the write hook will enforce.
     */
    function _detectTransferRestrictionOnNotify(address from, address to, uint256 value)
        internal
        view
        virtual
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @notice Enforces the cap for a direct transfer, reverting on violation.
     * @param from Sender address.
     * @param to Recipient address whose resulting balance is checked.
     * @param value Transfer amount.
     */
    function _transferred(address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestrictionOnNotify(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxBalance_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @notice Enforces the cap for a `transferFrom`, reverting on violation.
     * @param spender Approved spender initiating the transfer; the minter on the mint path.
     * @param from Sender address.
     * @param to Recipient address whose resulting balance is checked.
     * @param value Transfer amount.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestrictionOnNotify(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxBalance_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
