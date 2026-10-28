// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
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
     * @param maxTotalSupply_ Maximum total supply allowed, in token base units (scaled by `10 ** decimals()`).
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
    function canReturnTransferRestrictionCode(uint8 restrictionCode) public pure virtual override returns (bool) {
        return restrictionCode == CODE_MAX_TOTAL_SUPPLY_EXCEEDED || restrictionCode == CODE_SUPPLY_ORACLE_UNAVAILABLE;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns how much may still be minted before total supply reaches the cap.
     * @dev Mirrors what {_detectTransferRestriction} computes for a mint, so an integrator can size a
     * mint without simulating it. Never reverts. `0` when the cap is at or below the current supply.
     * @return restrictionCode `0` when the headroom is meaningful, otherwise the code a mint would
     * return ({CODE_SUPPLY_ORACLE_UNAVAILABLE} when `totalSupply()` cannot be read).
     * @return headroom Remaining mintable amount in token units; meaningless when `restrictionCode`
     * is non-zero.
     */
    function remainingMintable() public view virtual returns (uint8 restrictionCode, uint256 headroom) {
        (bool supplyAvailable, uint256 headroom_) = _remainingMintable();
        if (!supplyAvailable) {
            return (CODE_SUPPLY_ORACLE_UNAVAILABLE, 0);
        }
        return (uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK), headroom_);
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     * @dev Not `view` so that a subclass may record a mint through {_afterMintChecked}. This rule itself
     * never writes storage; a test asserts it.
     */
    function transferred(address from, address to, uint256 value) public virtual override(IERC3643IComplianceContract) {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc RuleTransferValidation
     * @dev Not `view`; see the 3-argument overload.
     */
    function transferred(address spender, address from, address to, uint256 value) public virtual override {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        virtual
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
     * @notice Enforces the max-total-supply restriction for a direct transfer, reverting on violation.
     * @param from Sender address; the zero address denotes a mint whose supply is checked.
     * @param to Recipient address.
     * @param value Transfer amount.
     */
    function _transferred(address from, address to, uint256 value) internal virtual {
        uint8 code = _detectTransferRestrictionOnNotify(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxTotalSupply_InvalidTransfer(address(this), from, to, value, code)
        );
        if (from == address(0)) {
            _afterMintChecked(value);
        }
    }

    /**
     * @notice Enforces the max-total-supply restriction for a `transferFrom`, reverting on violation.
     * @param spender Approved spender initiating the transfer.
     * @param from Sender address; the zero address denotes a mint whose supply is checked.
     * @param to Recipient address.
     * @param value Transfer amount.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal virtual {
        uint8 code = _detectTransferRestrictionOnNotify(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxTotalSupply_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
        if (from == address(0)) {
            _afterMintChecked(value);
        }
    }

    /**
     * @notice Called on the write path after a mint has passed every check; a no-op here.
     * @dev The extension point for a subclass that must record accepted mints (`RuleIssuanceCap`). It
     * receives the REAL minted amount even where {_detectTransferRestrictionOnNotify} is re-phased to
     * `value = 0` (ERC-3643 variants), so a check placed here cannot be skipped by the re-phasing.
     * WARNING: both `transferred` overloads are public and ungated here, which is safe only because this
     * contract writes nothing. A subclass that writes state in this hook MUST restrict both overloads to
     * its bound caller (as `RuleIssuanceCap` does with `onlyBoundToken`), or anyone can record mints.
     * @param value The amount minted.
     */
    function _afterMintChecked(uint256 value) internal virtual {}
}
