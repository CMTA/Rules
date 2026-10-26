// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {ERC3643ComplianceModule} from "RuleEngine/modules/ERC3643ComplianceModule.sol";
import {TokenBindingModule} from "RuleEngine/modules/TokenBindingModule.sol";
import {ITokenBinding} from "RuleEngine/interfaces/ITokenBinding.sol";
import {RuleMaxTotalSupplyBase} from "../../validation/abstract/base/RuleMaxTotalSupplyBase.sol";
import {RuleIssuanceCapInvariantStorage} from "./RuleIssuanceCapInvariantStorage.sol";

/**
 * @title RuleIssuanceCapBase
 * @notice Non-replenishing issuance cap: cumulative minting never exceeds `maxTotalSupply`, and burns do
 * NOT restore room. For a cap that burns do restore, deploy `RuleMaxTotalSupply` instead.
 * @dev Everything except the counter is inherited from `RuleMaxTotalSupplyBase`, including its live
 * `totalSupply()` check against the same cap. That check never rejects a mint the counter accepts while
 * every mint is counted (issuance >= supply), and it catches mints the counter missed, such as those made
 * while the rule was detached.
 *
 * Stateful, so `transferred` is restricted to the bound caller: bind the token when the rule is set
 * directly on it, or the RuleEngine when it sits behind one. One instance per token: the counter is that
 * token's history, so the observed token cannot be changed after deployment.
 */
abstract contract RuleIssuanceCapBase is
    RuleMaxTotalSupplyBase,
    ERC3643ComplianceModule,
    RuleIssuanceCapInvariantStorage
{
    /*//////////////////////////////////////////////////////////////
                             STATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Cumulative issuance in token base units: `initialIssued` plus every recorded mint. Never decreases.
     */
    uint256 public totalIssued;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param tokenContract_ Token whose mints are capped; fixed for the life of the rule.
     * @param issuanceCap_ Maximum cumulative issuance, in token base units.
     * @param initialIssued_ Issuance before the rule was installed; must be at least the current supply,
     * since cumulative issuance can never be below it.
     */
    constructor(address tokenContract_, uint256 issuanceCap_, uint256 initialIssued_)
        RuleMaxTotalSupplyBase(tokenContract_, issuanceCap_)
    {
        // The token was validated (has code, `totalSupply()` callable) by the parent constructor.
        (, uint256 supply) = _currentSupply();
        require(initialIssued_ >= supply, RuleIssuanceCap_InitialIssuedBelowSupply(initialIssued_, supply));
        totalIssued = initialIssued_;
        emit TotalIssuedInitialized(initialIssued_);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Compliance hook invoked when tokens are created; no-op (a RuleEngine forwards mints as `transferred`).
     */
    function created(address, uint256) external virtual override onlyBoundToken {}

    /**
     * @notice Compliance hook invoked when tokens are destroyed; no-op (burns never restore room).
     */
    function destroyed(address, uint256) external virtual override onlyBoundToken {}

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Binds the single caller allowed to notify mints (the token, or the RuleEngine in front of it).
     * @dev Reverts while a caller is bound; call `unbindToken` first to migrate.
     * @param token The token or RuleEngine to bind.
     */
    function bindToken(address token)
        public
        virtual
        override(ITokenBinding, TokenBindingModule)
        onlyTokenBindingManager
    {
        require(getTokenBound() == address(0), RuleIssuanceCap_TokenAlreadyBound());
        _bindToken(token);
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     * @dev Restricted to the bound caller, since an accepted mint is recorded.
     */
    function transferred(address from, address to, uint256 value)
        public
        virtual
        override(RuleMaxTotalSupplyBase, IERC3643IComplianceContract)
        onlyBoundToken
    {
        super.transferred(from, to, value);
    }

    /**
     * @notice Applies the cap to an operation carrying a spender; restricted to the bound caller.
     * @dev The spender is ignored: the cap is per token, not per minter.
     */
    function transferred(address spender, address from, address to, uint256 value)
        public
        virtual
        override
        onlyBoundToken
    {
        super.transferred(spender, from, to, value);
    }

    /**
     * @notice Returns whether this rule can produce the given restriction code (71, 50 or 51).
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) public pure virtual override returns (bool) {
        return restrictionCode == CODE_ISSUANCE_CAP_EXCEEDED || restrictionCode == CODE_RULE_NOT_BOUND
            || super.canReturnTransferRestrictionCode(restrictionCode);
    }

    /**
     * @notice Returns the message for a restriction code of this rule.
     */
    function messageForTransferRestriction(uint8 restrictionCode) public pure virtual override returns (string memory) {
        if (restrictionCode == CODE_ISSUANCE_CAP_EXCEEDED) {
            return TEXT_ISSUANCE_CAP_EXCEEDED;
        } else if (restrictionCode == CODE_RULE_NOT_BOUND) {
            return TEXT_RULE_NOT_BOUND;
        }
        return super.messageForTransferRestriction(restrictionCode);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Read path: the counter leg (code 71), then the inherited live-supply leg (codes 50 / 51).
     */
    function _detectTransferRestriction(address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        if (_ruleNotBound()) {
            return CODE_RULE_NOT_BOUND;
        }
        if (from == address(0) && _issuanceExceededBy(value)) {
            return CODE_ISSUANCE_CAP_EXCEEDED;
        }
        return super._detectTransferRestriction(from, to, value);
    }

    /**
     * @notice Records an accepted mint. Zero-value mints are a no-op.
     * @dev Re-checks the counter with the real amount: on a re-phased (ERC-3643) write path the inherited
     * check runs with `value = 0` and would not catch it.
     */
    function _afterMintChecked(uint256 value) internal virtual override {
        // Both slots are read once, into locals: `require` evaluates its error arguments on the success path too.
        uint256 issued = totalIssued;
        uint256 cap = maxTotalSupply;
        require(
            !_capExceededBy(issued, cap, value), RuleIssuanceCap_IssuanceCapExceeded(address(this), issued, cap, value)
        );
        if (value == 0) {
            return;
        }
        issued += value;
        totalIssued = issued;
        emit IssuanceRecorded(value, issued);
    }

    /**
     * @notice Remaining mintable amount: the smaller of the counter room and the live-supply room.
     */
    function _remainingMintable() internal view virtual override returns (bool supplyAvailable, uint256 headroom) {
        (supplyAvailable, headroom) = super._remainingMintable();
        if (!supplyAvailable) {
            return (false, 0);
        }
        uint256 counterRoom = _capHeadroom(totalIssued, maxTotalSupply);
        if (counterRoom < headroom) {
            headroom = counterRoom;
        }
    }

    /**
     * @notice Remaining mintable amount, or {CODE_RULE_NOT_BOUND} while no caller is bound (every mint reverts).
     */
    function remainingMintable() public view virtual override returns (uint8 restrictionCode, uint256 headroom) {
        if (_ruleNotBound()) {
            return (CODE_RULE_NOT_BOUND, 0);
        }
        return super.remainingMintable();
    }

    /**
     * @notice True while no token or RuleEngine is bound, so every `transferred` call reverts.
     */
    function _ruleNotBound() internal view virtual returns (bool) {
        return getTokenBound() == address(0);
    }

    /**
     * @notice Whether recording `value` would push cumulative issuance above the cap.
     */
    function _issuanceExceededBy(uint256 value) internal view virtual returns (bool) {
        return _capExceededBy(totalIssued, maxTotalSupply, value);
    }

    /**
     * @notice The observed token is fixed: the counter describes its history only, so `setTokenContract` always
     * reverts. `require(false, …)` rather than a bare `revert`, which solc reports as making the inherited setter
     * body unreachable.
     */
    function _authorizeTokenContractManager() internal view virtual override {
        require(false, RuleIssuanceCap_TokenContractLocked());
    }
}
