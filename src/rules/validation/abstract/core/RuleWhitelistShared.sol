// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/* ==== CMTAT === */
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
/* ==== Abstract contracts === */
import {RuleWhitelistInvariantStorage} from "../RuleAddressSet/invariantStorage/RuleWhitelistInvariantStorage.sol";
import {RuleNFTAdapter} from "./RuleNFTAdapter.sol";

/**
 * @title Rule Whitelist Shared
 * @notice Provides common logic for validating whitelist-based transfer restrictions.
 * @dev
 * - Implements ERC-3643–compatible `transferred` hooks to enforce whitelist checks.
 * - Defines utility functions for restriction code validation and message mapping.
 * - Inherits restriction code constants and messages from {RuleWhitelistInvariantStorage}.
 */
abstract contract RuleWhitelistShared is RuleNFTAdapter, RuleWhitelistInvariantStorage {
    /**
     * Indicate if the spender is verified or not
     */
    bool public checkSpender;

    /**
     * @notice Whether this rule permits minting (`from == address(0)`).
     * @dev Mint/burn permission is an EXPLICIT flag, never list membership of `address(0)`.
     *      The zero address is the ERC-20 mint/burn sentinel, not a participant: listing it would
     *      make `isVerified(address(0))` return `true`, contradicting ERC-3643 (which defines
     *      `isVerified` as "is this wallet a valid investor holding the required claims").
     *      Note this flag only gates the *operation*: a permitted mint still requires the RECIPIENT
     *      to be whitelisted, so `allowMint = true` is not a bypass.
     */
    bool public allowMint;

    /**
     * @notice Whether this rule permits burning (`to == address(0)`).
     * @dev See {allowMint}. A permitted burn still requires the SENDER to be whitelisted.
     */
    bool public allowBurn;

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyMintBurnManager() {
        _authorizeMintBurnManager();
        _;
    }

    modifier onlyCheckSpenderManager() {
        _authorizeCheckSpenderManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks whether a restriction code is recognized by this rule.
     * @dev
     * Used to verify if a returned restriction code belongs to the whitelist rule.
     * @param restrictionCode The restriction code to validate.
     * @return isKnown True if the restriction code is recognized by this rule, false otherwise.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode)
        external
        pure
        virtual
        override
        returns (bool isKnown)
    {
        return restrictionCode == CODE_ADDRESS_FROM_NOT_WHITELISTED
            || restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED
            || restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED || restrictionCode == CODE_MINT_NOT_ALLOWED
            || restrictionCode == CODE_BURN_NOT_ALLOWED;
    }

    /**
     * @notice Returns the human-readable message corresponding to a restriction code.
     * @dev
     * Returns a descriptive text that explains why a transfer was restricted.
     * @param restrictionCode The restriction code to decode.
     * @return message A human-readable explanation of the restriction.
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        external
        pure
        virtual
        override
        returns (string memory message)
    {
        if (restrictionCode == CODE_ADDRESS_FROM_NOT_WHITELISTED) {
            return TEXT_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED) {
            return TEXT_ADDRESS_TO_NOT_WHITELISTED;
        } else if (restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED) {
            return TEXT_ADDRESS_SPENDER_NOT_WHITELISTED;
        } else if (restrictionCode == CODE_MINT_NOT_ALLOWED) {
            return TEXT_MINT_NOT_ALLOWED;
        } else if (restrictionCode == CODE_BURN_NOT_ALLOWED) {
            return TEXT_BURN_NOT_ALLOWED;
        } else {
            return TEXT_CODE_NOT_FOUND;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enables or disables spender verification on delegated transfers.
     * @dev Restricted to the check-spender manager; emits {CheckSpenderUpdated}.
     * @param value The new state of the `checkSpender` flag.
     */
    function setCheckSpender(bool value) public virtual onlyCheckSpenderManager {
        _setCheckSpender(value);
    }

    /**
     * @notice Enables or disables minting through this rule.
     * @param value The new value of the `allowMint` flag.
     */
    function setAllowMint(bool value) public virtual onlyMintBurnManager {
        allowMint = value;
        emit AllowMintUpdated(value);
    }

    /**
     * @notice Enables or disables burning through this rule.
     * @param value The new value of the `allowBurn` flag.
     */
    function setAllowBurn(bool value) public virtual onlyMintBurnManager {
        allowBurn = value;
        emit AllowBurnUpdated(value);
    }

    /**
     * @notice ERC-3643 hook called when a transfer occurs.
     * @dev
     * - Validates that both `from` and `to` addresses are whitelisted.
     * - Reverts if any restriction code other than `TRANSFER_OK` is returned.
     * - Validation only; does not modify state.
     * - Should be called during token transfer logic to enforce whitelist compliance.
     * @param from The address sending tokens.
     * @param to The address receiving tokens.
     * @param value The token amount being transferred.
     */
    function transferred(address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC3643IComplianceContract)
    {
        _transferred(from, to, value);
    }

    /**
     * @notice hook called when a delegated transfer occurs (`transferFrom`).
     * @dev
     * - Validates that `spender`, `from`, and `to` are all whitelisted.
     * - Reverts if any restriction code other than `TRANSFER_OK` is returned.
     * - Validation only; does not modify state.
     * @param spender The address performing the transfer on behalf of another.
     * @param from The address from which tokens are transferred.
     * @param to The recipient address.
     * @param value The token amount being transferred.
     */
    function transferred(address spender, address from, address to, uint256 value) public view virtual override {
        _transferredFrom(spender, from, to, value);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal helper to update the {checkSpender} flag and emit {CheckSpenderUpdated}.
     * @dev The event lives here rather than at the call site so the constructors of the inheriting
     *      rules announce the initial value too, matching {_setAllowMintBurn}. Without it an indexer
     *      could reconstruct `allowMint` and `allowBurn` from genesis but had to special-case
     *      `checkSpender`.
     * @param value New flag value.
     */
    function _setCheckSpender(bool value) internal virtual {
        checkSpender = value;
        emit CheckSpenderUpdated(value);
    }

    /**
     * @notice Sets both mint/burn flags at once (deployment helper).
     * @param allowMint_ Whether minting is permitted.
     * @param allowBurn_ Whether burning is permitted.
     */
    function _setAllowMintBurn(bool allowMint_, bool allowBurn_) internal virtual {
        allowMint = allowMint_;
        allowBurn = allowBurn_;
        emit AllowMintUpdated(allowMint_);
        emit AllowBurnUpdated(allowBurn_);
    }

    /**
     * @notice Gates the mint/burn OPERATION, before any address is screened.
     * @dev Shared by {RuleWhitelistBase} and {RuleWhitelistWrapperBase} so the two can never drift.
     * @param from The sender (zero address for a mint).
     * @param to The recipient (zero address for a burn).
     * @return The restriction code, or TRANSFER_OK when the operation is permitted.
     */
    function _detectMintBurnRestriction(address from, address to) internal view virtual returns (uint8) {
        if (from == address(0) && !allowMint) {
            return CODE_MINT_NOT_ALLOWED;
        }
        if (to == address(0) && !allowBurn) {
            return CODE_BURN_NOT_ALLOWED;
        }
        return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Authorizes the caller to toggle `allowMint` / `allowBurn`; reverts otherwise.
     */
    function _authorizeMintBurnManager() internal view virtual;

    /**
     * @notice Authorizes the caller as check-spender manager; reverts otherwise.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     *      `view` by convention: an access-control hook checks and reverts, it never mutates state.
     */
    function _authorizeCheckSpenderManager() internal view virtual;

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferred(address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestriction(from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleWhitelist_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleWhitelist_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
