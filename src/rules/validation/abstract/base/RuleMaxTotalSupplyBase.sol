// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {TotalSupplyCapManager} from "../core/TotalSupplyCapManager.sol";

/**
 * @title RuleMaxTotalSupplyBase
 * @notice Restricts minting so that total supply never exceeds a maximum value.
 */
abstract contract RuleMaxTotalSupplyBase is RuleTransferValidation, TotalSupplyCapManager {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule with the token to observe and the supply cap.
     * @dev Routes through the same internal setters the public API uses, so the initial
     * configuration is announced by {TokenContractUpdated} and {MaxTotalSupplyUpdated} exactly like
     * every later change. A cap that is set once at deployment and never touched would otherwise
     * have no on-chain event trail at all.
     * @param tokenContract_ Address of the token whose `totalSupply` is checked; must not be the zero address.
     * @param maxTotalSupply_ Maximum total supply allowed.
     */
    constructor(address tokenContract_, uint256 maxTotalSupply_) {
        _setTokenContract(tokenContract_);
        _setMaxTotalSupply(maxTotalSupply_);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this rule can produce the given restriction code.
     * @param restrictionCode Restriction code to test.
     * @return True if `restrictionCode` is the max-total-supply-exceeded code.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_MAX_TOTAL_SUPPLY_EXCEEDED || restrictionCode == CODE_SUPPLY_ORACLE_UNAVAILABLE;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        if (restrictionCode == CODE_MAX_TOTAL_SUPPLY_EXCEEDED) {
            return TEXT_MAX_TOTAL_SUPPLY_EXCEEDED;
        } else if (restrictionCode == CODE_SUPPLY_ORACLE_UNAVAILABLE) {
            return TEXT_SUPPLY_ORACLE_UNAVAILABLE;
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
        address from,
        address,
        /* to */
        uint256 value
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        if (from == address(0)) {
            (bool supplyAvailable, bool exceeded) = _capExceeded(value);
            if (!supplyAvailable) {
                return CODE_SUPPLY_ORACLE_UNAVAILABLE;
            }
            if (exceeded) {
                return CODE_MAX_TOTAL_SUPPLY_EXCEEDED;
            }
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc RuleTransferValidation
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
     * @dev **This is the seam an ERC-3643 variant overrides.** It defaults to the pre-flight check,
     * which is correct for a token that notifies the rule BEFORE moving the value (CMTAT): the
     * observation still excludes `value`, so `value` must be counted.
     *
     * A token that notifies AFTERWARDS (ERC-3643 / T-REX) reports an observation that already
     * includes `value`; counting it again halves the effective cap. Such a variant overrides this
     * hook to re-ask the same question with nothing left to add:
     *
     * ```solidity
     * function _detectTransferRestrictionOnNotify(address from, address to, uint256)
     *     internal view override returns (uint8)
     * {
     *     return _detectTransferRestriction(from, to, 0);
     * }
     * ```
     *
     * The read path is deliberately NOT routed through here: a pre-flight view always runs before the
     * movement, on either kind of token, so it must always count `value`.
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
     * @notice Enforces the max-total-supply restriction for a direct transfer, reverting on violation.
     * @param from Sender address; the zero address denotes a mint whose supply is checked.
     * @param to Recipient address.
     * @param value Transfer amount.
     */
    function _transferred(address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestrictionOnNotify(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxTotalSupply_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @notice Enforces the max-total-supply restriction for a `transferFrom`, reverting on violation.
     * @param spender Approved spender initiating the transfer.
     * @param from Sender address; the zero address denotes a mint whose supply is checked.
     * @param to Recipient address.
     * @param value Transfer amount.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestrictionOnNotify(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxTotalSupply_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
