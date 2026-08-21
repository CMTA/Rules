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
import {VersionModule} from "../../../modules/VersionModule.sol";
import {RuleMintAllowanceInvariantStorage} from "./RuleMintAllowanceInvariantStorage.sol";

/**
 * @title RuleMintAllowanceBase
 * @notice Core logic for per-minter mint quota enforcement.
 * @dev Operators set the number of tokens each minter address is allowed to mint.
 *      Each mint reduces the minter's allowance. Allowances can be set to an absolute
 *      value or adjusted incrementally via `increaseMintAllowance`/`decreaseMintAllowance`.
 *
 *      The rule tracks mints via the 4-arg `transferred(spender, from=0, to, value)` path
 *      introduced in CMTAT v3.3. The 3-arg `transferred(from=0, to, value)` path has no
 *      minter identity and performs no deduction.
 *
 *      `detectTransferRestriction(from, to, value)` always returns TRANSFER_OK because
 *      the minter identity is unavailable in the 3-arg call; use
 *      `detectTransferRestrictionFrom(minter, address(0), to, amount)` to query allowance.
 *
 *      Callers of the state-modifying `transferred()` functions must be bound via
 *      `bindToken(ruleEngineAddress)` before minting starts. In a standard CMTAT +
 *      RuleEngine setup the RuleEngine address is the entity to bind.
 */
abstract contract RuleMintAllowanceBase is
    VersionModule,
    ERC3643ComplianceModule,
    RuleMintAllowanceInvariantStorage,
    IRule
{
    /*//////////////////////////////////////////////////////////////
                             STATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Remaining mint allowance for each minter address, in token base units
     */
    mapping(address minter => uint256 allowance) public mintAllowance;

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyAllowanceOperator() {
        _authorizeSetMintAllowance();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Compliance hook invoked when tokens are created (minted); no-op for this rule.
     */
    function created(address, uint256) external virtual override onlyBoundToken {}

    /**
     * @notice Compliance hook invoked when tokens are destroyed (burned); no-op for this rule.
     */
    function destroyed(address, uint256) external virtual override onlyBoundToken {}

    /**
     * @inheritdoc IRule
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override(IRule) returns (bool) {
        return restrictionCode == CODE_MINTER_ALLOWANCE_EXCEEDED;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets `minter`'s allowance to an absolute `amount`.
     * @param minter The minter whose allowance is set.
     * @param amount The absolute allowance to assign.
     */
    function setMintAllowance(address minter, uint256 amount) public virtual onlyAllowanceOperator {
        _setMintAllowance(minter, amount);
    }

    /**
     * @notice Increases `minter`'s allowance by `amount`.
     * @param minter The minter whose allowance is increased.
     * @param amount The amount to add to the allowance.
     */
    function increaseMintAllowance(address minter, uint256 amount) public virtual onlyAllowanceOperator {
        uint256 newAllowance = mintAllowance[minter] + amount;
        mintAllowance[minter] = newAllowance;
        emit MintAllowanceIncreased(minter, amount, newAllowance);
    }

    /**
     * @notice Decreases `minter`'s allowance by `amount`. Reverts if the reduction
     *         would underflow (i.e. `amount > current allowance`).
     * @param minter The minter whose allowance is decreased.
     * @param amount The amount to subtract from the allowance.
     */
    function decreaseMintAllowance(address minter, uint256 amount) public virtual onlyAllowanceOperator {
        uint256 current = mintAllowance[minter];
        require(amount <= current, RuleMintAllowance_DecreaseBelowZero(minter, current, amount));
        uint256 newAllowance = current - amount;
        mintAllowance[minter] = newAllowance;
        emit MintAllowanceDecreased(minter, amount, newAllowance);
    }

    /**
     * @notice Sets the allowance of every listed minter to zero.
     * @dev
     *      Batch operation: does not revert on minters that already have a zero allowance.
     *      Intended for migration: `unbindToken` does NOT clear `mintAllowance`, so call this
     *      before rebinding to a different RuleEngine/token if the previous quotas must not
     *      carry over. See the {bindToken} warning.
     * @param minters The minters whose allowances are cleared.
     */
    function clearMintAllowances(address[] calldata minters) public virtual onlyAllowanceOperator {
        for (uint256 i = 0; i < minters.length; ++i) {
            _setMintAllowance(minters[i], 0);
        }
    }

    /**
     * @notice Binds a caller to this rule. Reverts if a caller is already bound.
     * @dev Enforces single-target binding to prevent one allowance state from being
     *      shared across several RuleEngines/tokens. To migrate, call `unbindToken`
     *      first, then bind the new caller.
     * @dev WARNING: `unbindToken` does not clear `mintAllowance`. Quotas granted while the
     *      previous RuleEngine/token was bound remain in storage and are spendable by the same
     *      minters once a new caller is bound. The operator who controls rebinding also controls
     *      allowances, so the trust model is preserved, but integrators should be aware of this
     *      behavior. Call {clearMintAllowances} before rebinding to discard the previous quotas.
     * @param token The caller (RuleEngine/token) to bind to this rule.
     */
    function bindToken(address token)
        public
        virtual
        override(ITokenBinding, TokenBindingModule)
        onlyTokenBindingManager
    {
        require(getTokenBound() == address(0), RuleMintAllowance_TokenAlreadyBound());
        _bindToken(token);
    }

    /**
     * @dev 3-arg path: no minter identity available; performs no deduction.
     *      Mints always arrive via the 4-arg path in CMTAT v3.3+.
     * @param from The sender address (address(0) for mints).
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function transferred(address from, address to, uint256 value)
        public
        virtual
        override(IERC3643IComplianceContract)
        onlyBoundToken
    {
        _transferred(from, to, value);
    }

    /**
     * @dev 4-arg path: `spender` is the minter when `from == address(0)`.
     *      Deducts `value` from `mintAllowance[spender]`; reverts if insufficient.
     * @param spender The minter identity when `from == address(0)`.
     * @param from The sender address (address(0) for mints).
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function transferred(address spender, address from, address to, uint256 value)
        public
        virtual
        override(IRuleEngine)
        onlyBoundToken
    {
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
        if (restrictionCode == CODE_MINTER_ALLOWANCE_EXCEEDED) {
            return TEXT_MINTER_ALLOWANCE_EXCEEDED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /**
     * @dev Always returns TRANSFER_OK: the minter address is not available in the
     *      3-arg call. Call `detectTransferRestrictionFrom` to check a minter's quota.
     * @return The restriction code, always TRANSFER_OK.
     */
    function detectTransferRestriction(address, address, uint256)
        public
        view
        virtual
        override(IERC1404)
        returns (uint8)
    {
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC1404Extend
     */
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC1404Extend)
        returns (uint8)
    {
        return _detectTransferRestrictionFrom(spender, from, to, value);
    }

    /**
     * @dev Always returns true: use `canTransferFrom` to check mint allowance.
     * @return Always true.
     */
    function canTransfer(address, address, uint256)
        public
        view
        virtual
        override(IERC3643ComplianceRead)
        returns (bool)
    {
        return true;
    }

    /**
     * @inheritdoc IERC7551Compliance
     */
    function canTransferFrom(address spender, address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC7551Compliance)
        returns (bool)
    {
        return detectTransferRestrictionFrom(spender, from, to, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice 3-arg path helper: regular transfers carry no minter identity and are not tracked.
     */
    function _transferred(address, address, uint256) internal virtual {
        // 3-arg path: no minter identity; regular transfers are not tracked by this rule.
    }

    /**
     * @notice Deducts a mint from the minter's allowance on the 4-arg path.
     * @dev No-op unless `from == address(0)` (a mint). Reverts if `value` exceeds
     *      the minter's remaining allowance.
     * @param spender The minter identity.
     * @param from The sender address (must be address(0) to deduct).
     * @param value The amount minted.
     */
    function _transferredFrom(address spender, address from, address, uint256 value) internal virtual {
        if (from != address(0)) {
            return;
        }
        uint256 current = mintAllowance[spender];
        require(value <= current, RuleMintAllowance_AllowanceExceeded(address(this), spender, current, value));
        uint256 remaining = current - value;
        mintAllowance[spender] = remaining;
        emit MintAllowanceConsumed(spender, value, remaining);
    }

    /**
     * @notice Sets a minter's allowance to an absolute value and emits the event.
     * @param minter The minter whose allowance is set.
     * @param amount The absolute allowance to assign.
     */
    function _setMintAllowance(address minter, uint256 amount) internal virtual {
        mintAllowance[minter] = amount;
        emit MintAllowanceSet(minter, amount);
    }

    /**
     * @notice Computes whether a prospective mint would exceed the minter's allowance.
     * @dev Only mints (`from == address(0)`) are checked; other transfers return TRANSFER_OK.
     * @param spender The minter identity.
     * @param from The sender address (checked only when address(0)).
     * @param value The amount to be minted.
     * @return The restriction code (CODE_MINTER_ALLOWANCE_EXCEEDED or TRANSFER_OK).
     */
    function _detectTransferRestrictionFrom(address spender, address from, address, uint256 value)
        internal
        view
        virtual
        returns (uint8)
    {
        if (from == address(0) && mintAllowance[spender] < value) {
            return CODE_MINTER_ALLOWANCE_EXCEEDED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Authorizes the caller to set/adjust mint allowances; reverts if unauthorized.
     */
    function _authorizeSetMintAllowance() internal view virtual;
}
